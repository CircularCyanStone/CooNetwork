import Foundation

/// payload pipeline 入口的严格归一化器。
///
/// 这里的目标不是“尽量把任意值都转成 `NtkDynamicData`”，而是在进入 pipeline 前
/// 明确收窄输入边界并尽早失败：
/// - 只接受顶层结构化 payload（object / array）
/// - 拒绝顶层 scalar 和未知对象
/// - 保持 Foundation bridge（尤其 `NSNumber` / `NSString`）的判定结果稳定
///
/// 这与 `NtkDynamicData.from(_:)` 的宽松策略不同：这里不能对未知对象做字符串降级，
/// 否则脏输入会伪装成“看起来合法的 payload”继续进入 transform / decode 阶段。
enum StrictPayloadNormalizer {
    static func normalizeRoot(_ raw: Any) throws -> NtkDynamicData? {
        if isTopLevelScalar(raw) {
            return nil
        }

        if let object = try normalizeObjectRoot(raw) {
            return object
        }

        if let array = try normalizeArrayRoot(raw) {
            return array
        }

        return nil
    }

    private static func isTopLevelScalar(_ raw: Any) -> Bool {
        switch raw {
        case is String, is Bool, is Int, is Double, is NSNull, is NSString, is NSNumber:
            return true
        default:
            return false
        }
    }

    private static func normalizeObjectRoot(_ raw: Any) throws -> NtkDynamicData? {
        if let dict = raw as? [String: any Sendable] {
            return .strictObject(try normalizeDictionaryEntries(dict))
        }

        guard let dict = raw as? NSDictionary else {
            return nil
        }

        return .strictObject(try normalizeNSDictionaryEntries(dict))
    }

    private static func normalizeArrayRoot(_ raw: Any) throws -> NtkDynamicData? {
        if let array = raw as? [any Sendable] {
            return .strictArray(try normalizeArrayElements(array))
        }

        guard let array = raw as? NSArray else {
            return nil
        }

        return .strictArray(try normalizeNSArrayElements(array))
    }

    private static func normalizeNode(_ value: Any) throws -> NtkDynamicData {
        switch value {
        case let number as NSNumber:
            return normalizeNSNumber(number)
        case let string as String:
            return NtkDynamicData(string: string)
        case let bool as Bool:
            return NtkDynamicData(bool: bool)
        case let int as Int:
            return NtkDynamicData(int: int)
        case let double as Double:
            return NtkDynamicData(double: double)
        case is NSNull:
            return NtkDynamicData()
        case let string as NSString:
            return NtkDynamicData(string: String(string))
        case let dict as [String: any Sendable]:
            return .strictObject(try normalizeDictionaryEntries(dict))
        case let array as [any Sendable]:
            return .strictArray(try normalizeArrayElements(array))
        case let dict as NSDictionary:
            return .strictObject(try normalizeNSDictionaryEntries(dict))
        case let array as NSArray:
            return .strictArray(try normalizeNSArrayElements(array))
        default:
            throw NtkError.typeMismatch
        }
    }

    private static func normalizeDictionaryEntries(
        _ dictionary: [String: any Sendable]
    ) throws -> [String: NtkDynamicData] {
        var normalized: [String: NtkDynamicData] = [:]
        for (key, value) in dictionary {
            normalized[key] = try normalizeNode(value)
        }
        return normalized
    }

    private static func normalizeNSDictionaryEntries(
        _ dictionary: NSDictionary
    ) throws -> [String: NtkDynamicData] {
        var normalized: [String: NtkDynamicData] = [:]
        for (key, value) in dictionary {
            guard let key = key as? String else {
                throw NtkError.typeMismatch
            }
            normalized[key] = try normalizeNode(value)
        }
        return normalized
    }

    private static func normalizeArrayElements(
        _ array: [any Sendable]
    ) throws -> [NtkDynamicData] {
        try array.map(normalizeNode)
    }

    private static func normalizeNSArrayElements(
        _ array: NSArray
    ) throws -> [NtkDynamicData] {
        try array.map { element in
            try normalizeNode(element)
        }
    }

    private static func normalizeNSNumber(_ number: NSNumber) -> NtkDynamicData {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return NtkDynamicData(bool: number.boolValue)
        }

        let doubleValue = number.doubleValue
        if floor(doubleValue) == doubleValue,
           doubleValue >= Double(Int.min),
           doubleValue <= Double(Int.max) {
            return NtkDynamicData(int: Int(doubleValue))
        }
        return NtkDynamicData(double: doubleValue)
    }
}
