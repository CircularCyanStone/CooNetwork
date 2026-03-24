import Foundation

public enum NtkPayload: Sendable {
    case data(Data)
    case dynamic(NtkDynamicData)

    public static func normalize(from raw: Any) throws -> NtkPayload {
        if let data = raw as? Data {
            return .data(data)
        }

        guard let dynamic = try StrictPayloadNormalizer.normalizeRoot(raw) else {
            throw NtkError.typeMismatch
        }

        return .dynamic(dynamic)
    }
}

private enum StrictPayloadNormalizer {
    static func normalizeRoot(_ raw: Any) throws -> NtkDynamicData? {
        if isTopLevelScalar(raw) {
            return nil
        }

        if let object = try normalizeJSONObject(raw) {
            return object
        }

        if let array = try normalizeJSONArray(raw) {
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

    private static func normalizeJSONObject(_ raw: Any) throws -> NtkDynamicData? {
        if let dict = raw as? [String: any Sendable] {
            return .strictObject(try normalizeDictionary(dict))
        }

        guard let dict = raw as? NSDictionary else {
            return nil
        }

        return .strictObject(try normalizeNSDictionary(dict))
    }

    private static func normalizeJSONArray(_ raw: Any) throws -> NtkDynamicData? {
        if let array = raw as? [any Sendable] {
            return .strictArray(try array.map(normalizeValue))
        }

        guard let array = raw as? NSArray else {
            return nil
        }

        return .strictArray(try normalizeNSArray(array))
    }

    private static func normalizeDictionary(_ dict: [String: any Sendable]) throws -> [String: NtkDynamicData] {
        var normalized: [String: NtkDynamicData] = [:]
        for (key, value) in dict {
            normalized[key] = try normalizeValue(value)
        }
        return normalized
    }

    private static func normalizeValue(_ value: Any) throws -> NtkDynamicData {
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
            return .strictObject(try normalizeDictionary(dict))
        case let array as [any Sendable]:
            return .strictArray(try array.map(normalizeValue))
        case let dict as NSDictionary:
            return .strictObject(try normalizeNSDictionary(dict))
        case let array as NSArray:
            return .strictArray(try normalizeNSArray(array))
        default:
            throw NtkError.typeMismatch
        }
    }

    private static func normalizeNSDictionary(_ dict: NSDictionary) throws -> [String: NtkDynamicData] {
        var normalized: [String: NtkDynamicData] = [:]
        for (key, value) in dict {
            guard let key = key as? String else {
                throw NtkError.typeMismatch
            }
            normalized[key] = try normalizeValue(value)
        }
        return normalized
    }

    private static func normalizeNSArray(_ array: NSArray) throws -> [NtkDynamicData] {
        try array.map { element in
            try normalizeValue(element)
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
