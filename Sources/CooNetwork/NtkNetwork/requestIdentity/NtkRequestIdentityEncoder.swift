import Foundation

/// 将请求 key 使用的数据编码成跨运行、跨字典插入顺序都稳定的二进制格式。
///
/// 不能使用 `String(describing:)`、JSON 文本或分隔符拼接：前者可能随类型实现和系统版本变化，
/// JSON 会丢失一部分 Swift 数值类型信息，简单分隔符还会让字段内容与结构边界发生碰撞。本编码器
/// 因而给每个值写入明确类型 tag，并用固定宽度长度前缀划分 payload。它只产生稳定字节，最终
/// SHA-256 和算法版本由 `NtkRequestIdentityBuilder` 负责。
struct NtkRequestIdentityEncoder {

    /// 值类型在持久化字节协议中的编号。
    ///
    /// signed 各整数宽度共享一个语义类别，unsigned 各宽度共享另一个类别；Float 与 Double
    /// 保持不同类别和位宽。枚举 rawValue、成员顺序或编码规则一旦变化，相同请求就会得到新 key，
    /// 因此必须同步升级持久化格式版本，不能原地修改。当前仍使用历史前缀
    /// `ntk-identity-v2`，仅为继续命中已落盘缓存；它不再代表公开 API 的命名。
    private enum Tag: UInt8 {
        case string = 1
        case boolFalse
        case boolTrue
        case signedInteger
        case unsignedInteger
        case float32
        case float64
        case data
        case url
        case uuid
        case date
        case null
        case dictionary
        case array
    }

    /// 当前编码器已经追加的完整 frame 序列。每个嵌套值使用独立 encoder，完成后整体并入父级。
    private var bytes = Data()

    /// 测试及递归入口：为单个动态值生成完整的“类型 tag + 长度 + payload”表示。
    ///
    /// `path` 不进入编码，只用于失败时准确指出不支持值在参数树中的位置；因此诊断信息不会
    /// 改变最终 key。
    static func encodeValue(_ value: any Sendable, path: String) throws -> Data {
        var encoder = NtkRequestIdentityEncoder()
        try encoder.appendValue(value, path: path)
        return encoder.data
    }

    /// 返回已经完成的稳定字节。`Data` 是值类型，调用方拿不到内部可变缓冲区的引用。
    var data: Data {
        bytes
    }

    /// 追加一个不可歧义的基础 frame。
    ///
    /// 布局固定为 `[1 byte tag][8 bytes UInt64 big-endian length][payload]`。长度前缀意味着
    /// payload 内可以安全包含任意字节，不需要转义，也不会把 `ab`+`c` 与 `a`+`bc` 混为一谈。
    mutating func appendField(tag: UInt8, payload: Data) {
        bytes.append(tag)
        bytes.appendUInt64(UInt64(payload.count))
        bytes.append(payload)
    }

    /// 以 UTF-8 payload 写入字符串字段；字段含义由调用方提供的顶层 tag 或值类型 tag 决定。
    mutating func appendStringField(tag: UInt8, value: String) {
        appendField(tag: tag, payload: Data(value.utf8))
    }

    /// 编码可选字符串，并用首字节显式区分 nil 与非 nil。
    ///
    /// 非 nil 的空字符串表示为 `[1]`，nil 表示为 `[0]`，所以二者不会产生同一请求 key。
    mutating func appendOptionalStringField(tag: UInt8, value: String?) {
        var payload = Data()
        if let value {
            payload.append(1)
            payload.append(Data(value.utf8))
        } else {
            payload.append(0)
        }
        appendField(tag: tag, payload: payload)
    }

    /// 编码已经整理为字符串值的字典，当前用于 Header 和附加 request identity values。
    ///
    /// 先写元素数量，再按 Swift `String` 顺序排列 key；key 和 value 分别带长度前缀。因此字典
    /// 的插入顺序不影响结果，而附加值中可能出现的任意字符也不会破坏结构边界。
    mutating func appendStringDictionaryField(tag: UInt8, value: [String: String]) {
        var payload = Data()
        payload.appendCount(value.count)
        for key in value.keys.sorted() {
            payload.appendLengthPrefixed(Data(key.utf8))
            payload.appendLengthPrefixed(Data(value[key, default: ""].utf8))
        }
        appendField(tag: tag, payload: payload)
    }

    /// 编码参数或嵌套对象字典。
    ///
    /// key 按稳定顺序写入；每个 value 递归生成自己的完整类型 frame，所以字典值不需要额外
    /// 长度前缀也能被唯一解释。强制解包是安全的：key 来自同一不可变字典的 `keys` 快照，
    /// 编码过程中没有任何代码会修改该字典。
    mutating func appendValueDictionaryField(
        tag: UInt8,
        value: [String: any Sendable],
        path: String
    ) throws {
        var payload = Data()
        payload.appendCount(value.count)
        for key in value.keys.sorted() {
            payload.appendLengthPrefixed(Data(key.utf8))
            var valueEncoder = NtkRequestIdentityEncoder()
            try valueEncoder.appendValue(value[key]!, path: "\(path).\(key)")
            payload.append(valueEncoder.data)
        }
        appendField(tag: tag, payload: payload)
    }

    /// 根据运行时的精确 Swift 类型选择编码规则。
    ///
    /// `as` 可能发生 Foundation bridge，例如 `NSNumber` 可以被桥接成 Bool 或 Int；额外比较
    /// `dynamicType` 可以阻止这种隐式转换，让白名单外类型明确失败，而不是在不同运行环境中
    /// 悄悄落入另一种表示。失败只包含 path 和类型名，不包含值本身。
    private mutating func appendValue(_ value: any Sendable, path: String) throws {
        let dynamicType: Any.Type = type(of: value)

        switch value {
        // String 与 Bool 使用独立 tag；Bool 的真假也使用不同 tag，因此不需要 payload。
        case let value as String where dynamicType == String.self:
            appendStringField(tag: Tag.string.rawValue, value: value)
        case let value as Bool where dynamicType == Bool.self:
            appendField(
                tag: value ? Tag.boolTrue.rawValue : Tag.boolFalse.rawValue,
                payload: Data()
            )
        // 所有有符号整数宽度按“数学整数”统一为十进制 UTF-8；同值 Int8 与 Int64 key 相同。
        case let value as Int where dynamicType == Int.self:
            appendStringField(tag: Tag.signedInteger.rawValue, value: String(value))
        case let value as Int8 where dynamicType == Int8.self:
            appendStringField(tag: Tag.signedInteger.rawValue, value: String(value))
        case let value as Int16 where dynamicType == Int16.self:
            appendStringField(tag: Tag.signedInteger.rawValue, value: String(value))
        case let value as Int32 where dynamicType == Int32.self:
            appendStringField(tag: Tag.signedInteger.rawValue, value: String(value))
        case let value as Int64 where dynamicType == Int64.self:
            appendStringField(tag: Tag.signedInteger.rawValue, value: String(value))
        // 无符号整数与有符号整数使用不同 tag，避免 UInt(1) 与 Int(1) 混为同一类型。
        case let value as UInt where dynamicType == UInt.self:
            appendStringField(tag: Tag.unsignedInteger.rawValue, value: String(value))
        case let value as UInt8 where dynamicType == UInt8.self:
            appendStringField(tag: Tag.unsignedInteger.rawValue, value: String(value))
        case let value as UInt16 where dynamicType == UInt16.self:
            appendStringField(tag: Tag.unsignedInteger.rawValue, value: String(value))
        case let value as UInt32 where dynamicType == UInt32.self:
            appendStringField(tag: Tag.unsignedInteger.rawValue, value: String(value))
        case let value as UInt64 where dynamicType == UInt64.self:
            appendStringField(tag: Tag.unsignedInteger.rawValue, value: String(value))
        // 浮点值保留 IEEE 位模式和原始位宽。NaN/Infinity 没有稳定的业务数值语义，直接拒绝；
        // 大端转换保证编码不依赖当前 CPU 字节序。
        case let value as Float where dynamicType == Float.self:
            guard value.isFinite else {
                throw nonFiniteError(value, path: path)
            }
            var bitPattern = value.bitPattern.bigEndian
            let payload = withUnsafeBytes(of: &bitPattern) { Data($0) }
            appendField(tag: Tag.float32.rawValue, payload: payload)
        case let value as Double where dynamicType == Double.self:
            guard value.isFinite else {
                throw nonFiniteError(value, path: path)
            }
            var bitPattern = value.bitPattern.bigEndian
            let payload = withUnsafeBytes(of: &bitPattern) { Data($0) }
            appendField(tag: Tag.float64.rawValue, payload: payload)
        // Foundation 值使用定义明确的原始表示，不经过描述字符串。
        case let value as Data where dynamicType == Data.self:
            appendField(tag: Tag.data.rawValue, payload: value)
        case let value as URL where dynamicType == URL.self:
            appendStringField(tag: Tag.url.rawValue, value: value.absoluteString)
        case let value as UUID where dynamicType == UUID.self:
            var uuid = value.uuid
            let payload = withUnsafeBytes(of: &uuid) { Data($0) }
            appendField(tag: Tag.uuid.rawValue, payload: payload)
        case let value as Date where dynamicType == Date.self:
            let interval = value.timeIntervalSinceReferenceDate
            guard interval.isFinite else {
                throw nonFiniteError(value, path: path)
            }
            var bitPattern = interval.bitPattern.bigEndian
            let payload = withUnsafeBytes(of: &bitPattern) { Data($0) }
            appendField(tag: Tag.date.rawValue, payload: payload)
        // null 拥有独立 tag；它与缺少字典 key、空字符串或空容器都不相同。
        case is NSNull where dynamicType == NSNull.self:
            appendField(tag: Tag.null.rawValue, payload: Data())
        // 容器递归编码：字典忽略插入顺序，数组保留元素顺序和位置。
        case let value as [String: any Sendable]:
            try appendValueDictionaryField(
                tag: Tag.dictionary.rawValue,
                value: value,
                path: path
            )
        case let value as [any Sendable]:
            try appendArray(value, path: path)
        // NtkDynamicData 不使用 NSObject.description，而是展开其不可变内部 storage，再复用同一规则。
        case let value as NtkDynamicData where dynamicType == NtkDynamicData.self:
            try appendDynamicDataValue(value.requestIdentityValue, path: path)
        default:
            throw NtkRequestIdentityBuilder.BuildError.unsupportedValue(
                path: path,
                type: String(reflecting: dynamicType)
            )
        }
    }

    /// 编码顺序敏感的数组。
    ///
    /// 元素数量先写入 payload，每个元素随后按原索引递归编码；path 追加 `[index]` 只用于失败
    /// 定位。因为元素本身是完整 frame，异构数组也能保持清晰的类型和边界。
    private mutating func appendArray(_ value: [any Sendable], path: String) throws {
        var payload = Data()
        payload.appendCount(value.count)
        for (index, element) in value.enumerated() {
            var elementEncoder = NtkRequestIdentityEncoder()
            try elementEncoder.appendValue(element, path: "\(path)[\(index)]")
            payload.append(elementEncoder.data)
        }
        appendField(tag: Tag.array.rawValue, payload: payload)
    }

    /// 把 `NtkDynamicData` 的封闭存储枚举桥接回 request identity encoder 支持的值集合。
    ///
    /// 这样动态响应/参数对象与内容等价的普通 Swift 字典或数组得到相同表示，而不是因为外层
    /// 包装类型不同产生无意义的 key 差异。
    private mutating func appendDynamicDataValue(
        _ value: NtkDynamicRequestIdentityValue,
        path: String
    ) throws {
        switch value {
        case .dictionary(let dictionary):
            try appendValue(dictionary, path: path)
        case .array(let array):
            try appendValue(array, path: path)
        case .string(let string):
            try appendValue(string, path: path)
        case .int(let int):
            try appendValue(int, path: path)
        case .double(let double):
            try appendValue(double, path: path)
        case .bool(let bool):
            try appendValue(bool, path: path)
        case .null:
            try appendValue(NSNull(), path: path)
        }
    }

    /// 构造脱敏的非有限数值错误；只记录路径和动态类型，绝不插入实际数值。
    private func nonFiniteError<T>(_ value: T, path: String) -> NtkRequestIdentityBuilder.BuildError {
        .nonFiniteValue(
            path: path,
            type: String(reflecting: type(of: value))
        )
    }
}

private extension Data {

    /// 容器元素数量固定编码为 UInt64，避免 Int 在 32/64 位平台上的宽度差异进入持久化格式。
    mutating func appendCount(_ count: Int) {
        appendUInt64(UInt64(count))
    }

    /// 写入任意字节串前先写其长度，用于字典 key/value 等没有独立类型 frame 的片段。
    mutating func appendLengthPrefixed(_ value: Data) {
        appendUInt64(UInt64(value.count))
        append(value)
    }

    /// 使用网络序写入固定八字节整数，使相同输入在不同 CPU 字节序上得到相同编码。
    mutating func appendUInt64(_ value: UInt64) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { buffer in
            append(contentsOf: buffer)
        }
    }
}
