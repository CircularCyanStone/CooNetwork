import Foundation

struct NtkCanonicalIdentityEncoder {

    // 持久化身份格式不变量：tag 顺序不可调整；变更必须同步升级身份算法版本。
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

    private var bytes = Data()

    static func encodeValue(_ value: any Sendable, path: String) throws -> Data {
        var encoder = NtkCanonicalIdentityEncoder()
        try encoder.appendValue(value, path: path)
        return encoder.data
    }

    var data: Data {
        bytes
    }

    mutating func appendField(tag: UInt8, payload: Data) {
        // 持久化身份格式不变量：frame 固定为 tag、UInt64 大端长度、payload；变更必须同步升级身份算法版本。
        bytes.append(tag)
        bytes.appendUInt64(UInt64(payload.count))
        bytes.append(payload)
    }

    mutating func appendStringField(tag: UInt8, value: String) {
        appendField(tag: tag, payload: Data(value.utf8))
    }

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

    mutating func appendStringDictionaryField(tag: UInt8, value: [String: String]) {
        var payload = Data()
        payload.appendCount(value.count)
        // 持久化身份格式不变量：字典键按 String 顺序排序；变更必须同步升级身份算法版本。
        for key in value.keys.sorted() {
            payload.appendLengthPrefixed(Data(key.utf8))
            payload.appendLengthPrefixed(Data(value[key, default: ""].utf8))
        }
        appendField(tag: tag, payload: payload)
    }

    mutating func appendValueDictionaryField(
        tag: UInt8,
        value: [String: any Sendable],
        path: String
    ) throws {
        var payload = Data()
        payload.appendCount(value.count)
        // 持久化身份格式不变量：字典键按 String 顺序排序；变更必须同步升级身份算法版本。
        for key in value.keys.sorted() {
            payload.appendLengthPrefixed(Data(key.utf8))
            var valueEncoder = NtkCanonicalIdentityEncoder()
            try valueEncoder.appendValue(value[key]!, path: "\(path).\(key)")
            payload.append(valueEncoder.data)
        }
        appendField(tag: tag, payload: payload)
    }

    private mutating func appendValue(_ value: any Sendable, path: String) throws {
        let dynamicType: Any.Type = type(of: value)

        switch value {
        case let value as String where dynamicType == String.self:
            appendStringField(tag: Tag.string.rawValue, value: value)
        case let value as Bool where dynamicType == Bool.self:
            appendField(
                tag: value ? Tag.boolTrue.rawValue : Tag.boolFalse.rawValue,
                payload: Data()
            )
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
        case let value as Float where dynamicType == Float.self:
            guard value.isFinite else {
                throw nonFiniteFailure(value, path: path)
            }
            var bitPattern = value.bitPattern.bigEndian
            let payload = withUnsafeBytes(of: &bitPattern) { Data($0) }
            appendField(tag: Tag.float32.rawValue, payload: payload)
        case let value as Double where dynamicType == Double.self:
            guard value.isFinite else {
                throw nonFiniteFailure(value, path: path)
            }
            var bitPattern = value.bitPattern.bigEndian
            let payload = withUnsafeBytes(of: &bitPattern) { Data($0) }
            appendField(tag: Tag.float64.rawValue, payload: payload)
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
                throw nonFiniteFailure(value, path: path)
            }
            var bitPattern = interval.bitPattern.bigEndian
            let payload = withUnsafeBytes(of: &bitPattern) { Data($0) }
            appendField(tag: Tag.date.rawValue, payload: payload)
        case is NSNull where dynamicType == NSNull.self:
            appendField(tag: Tag.null.rawValue, payload: Data())
        case let value as [String: any Sendable]:
            try appendValueDictionaryField(
                tag: Tag.dictionary.rawValue,
                value: value,
                path: path
            )
        case let value as [any Sendable]:
            try appendArray(value, path: path)
        case let value as NtkDynamicData where dynamicType == NtkDynamicData.self:
            try appendDynamicValue(value.identityValue, path: path)
        default:
            throw NtkRequestIdentityBuilder.Failure.unsupportedValue(
                path: path,
                type: String(reflecting: dynamicType)
            )
        }
    }

    private mutating func appendArray(_ value: [any Sendable], path: String) throws {
        var payload = Data()
        payload.appendCount(value.count)
        for (index, element) in value.enumerated() {
            var elementEncoder = NtkCanonicalIdentityEncoder()
            try elementEncoder.appendValue(element, path: "\(path)[\(index)]")
            payload.append(elementEncoder.data)
        }
        appendField(tag: Tag.array.rawValue, payload: payload)
    }

    private mutating func appendDynamicValue(
        _ value: NtkDynamicIdentityValue,
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

    private func nonFiniteFailure<T>(_ value: T, path: String) -> NtkRequestIdentityBuilder.Failure {
        .nonFiniteValue(
            path: path,
            type: String(reflecting: type(of: value))
        )
    }
}

private extension Data {

    mutating func appendCount(_ count: Int) {
        appendUInt64(UInt64(count))
    }

    mutating func appendLengthPrefixed(_ value: Data) {
        appendUInt64(UInt64(value.count))
        append(value)
    }

    mutating func appendUInt64(_ value: UInt64) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { buffer in
            append(contentsOf: buffer)
        }
    }
}
