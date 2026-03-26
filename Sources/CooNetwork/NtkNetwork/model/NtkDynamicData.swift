//
//  NtkDynamicData.swift
//  NtkNetwork
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// NtkDynamicData - 支持多种数据类型的动态数据结构
/// 用于处理网络响应中的动态数据，支持 Dictionary<String, any Sendable>、Int、Bool、String 等多种类型
/// 提供类型安全的访问接口和便利的下标语法支持
@objcMembers
@dynamicMemberLookup
public final class NtkDynamicData: NSObject, Sendable, Codable {

    // MARK: - Core Storage

    /// 内部存储枚举
    /// 将类型标记与值绑定在一起，确保类型与值始终一致
    private enum Storage: Sendable {
        case dictionary([String: any Sendable])
        case array([any Sendable])
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null
    }

    /// 状态码的内部存储
    private let storage: Storage

    // MARK: - Initializers

    /// 从字典初始化
    public init(dictionary: [String: any Sendable]) {
        self.storage = .dictionary(dictionary)
        super.init()
    }

    /// 从数组初始化
    public init(array: [any Sendable]) {
        self.storage = .array(array)
        super.init()
    }

    /// 从字符串初始化
    public init(string: String) {
        self.storage = .string(string)
        super.init()
    }

    /// 从整数初始化
    public init(int: Int) {
        self.storage = .int(int)
        super.init()
    }

    /// 从双精度浮点数初始化
    public init(double: Double) {
        self.storage = .double(double)
        super.init()
    }

    /// 从布尔值初始化
    public init(bool: Bool) {
        self.storage = .bool(bool)
        super.init()
    }

    /// 空值初始化
    public override init() {
        self.storage = .null
        super.init()
    }

    // MARK: - Static Factories

    /// 从任意Sendable值创建NtkDynamicData
    public static func from(_ value: any Sendable) -> NtkDynamicData {
        switch value {
        case let dict as [String: any Sendable]:
            return NtkDynamicData(dictionary: dict)
        case let array as [any Sendable]:
            return NtkDynamicData(array: array)
        case let dict as NSDictionary:
            if let bridged = dict as? [String: any Sendable] {
                return NtkDynamicData(dictionary: bridged)
            }
            return NtkDynamicData(string: String(describing: dict))
        case let array as NSArray:
            if let bridged = array as? [any Sendable] {
                return NtkDynamicData(array: bridged)
            }
            return NtkDynamicData(string: String(describing: array))
        case let string as NSString:
            return NtkDynamicData(string: String(string))
        case let number as NSNumber:
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
        default:
            // 对于其他类型，尝试转换为字符串
            return NtkDynamicData(string: String(describing: value))
        }
    }


    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.storage = .null
            return
        }

        if let dict = try? container.decode([String: NtkDynamicData].self) {
            var convertedDict: [String: any Sendable] = [:]
            for (key, value) in dict {
                convertedDict[key] = value.sendableValue
            }
            self.storage = .dictionary(convertedDict)
            return
        }

        if let array = try? container.decode([NtkDynamicData].self) {
            let convertedArray = array.map { $0.sendableValue }
            self.storage = .array(convertedArray)
            return
        }

        if let string = try? container.decode(String.self) {
            self.storage = .string(string)
            return
        }

        if let int = try? container.decode(Int.self) {
            self.storage = .int(int)
            return
        }

        if let double = try? container.decode(Double.self) {
            self.storage = .double(double)
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self.storage = .bool(bool)
            return
        }

        throw NtkError.responseSerializationFailed(
            reason: .dataDecodingFailed(
                request: nil,
                clientResponse: nil,
                recoveredResponse: nil,
                rawPayload: nil,
                underlyingError: DecodingError.typeMismatch(
                    NtkDynamicData.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "无法解码为任何支持的类型")
                )
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch storage {
        case .dictionary(let dict):
            var dynamicDict: [String: NtkDynamicData] = [:]
            for (key, value) in dict {
                dynamicDict[key] = NtkDynamicData.from(value)
            }
            try container.encode(dynamicDict)
        case .array(let array):
            let dynamicArray = array.map { NtkDynamicData.from($0) }
            try container.encode(dynamicArray)
        case .string(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .bool(let v):
            try container.encode(v)
        case .null:
            try container.encodeNil()
        }
    }

    // MARK: - Internal Bridging

    /// 获取内部存储的 Sendable 值
    private var sendableValue: any Sendable {
        switch storage {
        case .dictionary(let v): return v
        case .array(let v):      return v
        case .string(let v):     return v
        case .int(let v):        return v
        case .double(let v):     return v
        case .bool(let v):       return v
        case .null:              return NSNull()
        }
    }
}

// MARK: - Typed Accessors

extension NtkDynamicData {

    /// 获取字典值
    /// - Returns: 字典值或nil
    public func getDictionary() -> [String: any Sendable]? {
        if case .dictionary(let v) = storage { return v }
        return nil
    }

    /// 获取数组值
    /// - Returns: 数组值或nil
    public func getArray() -> [any Sendable]? {
        if case .array(let v) = storage { return v }
        return nil
    }

    /// 获取字符串值
    /// - Returns: 字符串值或nil
    public func getString() -> String? {
        if case .string(let v) = storage { return v }
        return nil
    }

    /// 获取整数值
    /// - Returns: 整数值或nil
    public func getInt() -> Int? {
        if case .int(let v) = storage { return v }
        return nil
    }

    /// 获取双精度浮点数值
    /// - Returns: 双精度浮点数值或nil
    public func getDouble() -> Double? {
        if case .double(let v) = storage { return v }
        return nil
    }

    /// 获取布尔值
    /// - Returns: 布尔值或nil
    public func getBool() -> Bool? {
        if case .bool(let v) = storage { return v }
        return nil
    }

    /// 检查是否为空值
    /// - Returns: 是否为空值
    public func isNull() -> Bool {
        if case .null = storage { return true }
        return false
    }

    /// 通用获取值方法，支持类型转换
    /// - Parameter type: 目标类型
    /// - Returns: 转换后的值或抛出错误
    public func getValue<T>(as type: T.Type) throws -> T {
        switch type {
        case is String.Type:
            switch storage {
            case .string(let v): return v as! T
            case .int(let v):    return String(v) as! T
            case .double(let v): return String(v) as! T
            case .bool(let v):   return String(v) as! T
            case .null:          return "" as! T
            default:             throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
            }

        case is Int.Type:
            switch storage {
            case .int(let v):    return v as! T
            case .string(let v):
                if let intValue = Int(v) { return intValue as! T }
                throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
            case .double(let v): return Int(v) as! T
            case .bool(let v):   return (v ? 1 : 0) as! T
            default:             throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
            }

        case is Double.Type:
            switch storage {
            case .double(let v): return v as! T
            case .string(let v):
                if let doubleValue = Double(v) { return doubleValue as! T }
                throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
            case .int(let v):    return Double(v) as! T
            case .bool(let v):   return (v ? 1.0 : 0.0) as! T
            default:             throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
            }

        case is Bool.Type:
            switch storage {
            case .bool(let v):   return v as! T
            case .string(let v):
                let lower = v.lowercased()
                return (lower == "true" || lower == "1") as! T
            case .int(let v):    return (v != 0) as! T
            case .double(let v): return (v != 0.0) as! T
            default:             throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
            }

        case is [String: any Sendable].Type:
            if let value = getDictionary() { return value as! T }
            throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))

        case is [any Sendable].Type:
            if let value = getArray() { return value as! T }
            throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))

        default:
            throw NtkError.responseSerializationFailed(reason: .dataTypeMismatch(request: nil, clientResponse: nil, recoveredResponse: nil, underlyingError: nil))
        }
    }
}

// MARK: - Subscripts

extension NtkDynamicData {

    /// 字典类型的字符串下标访问
    /// - Parameter key: 字典键
    /// - Returns: 对应的NtkDynamicData值或nil
    public subscript(key: String) -> NtkDynamicData? {
        guard let dict = getDictionary() else { return nil }
        guard let value = dict[key] else { return nil }
        return NtkDynamicData.from(value)
    }

    /// 数组类型的整数下标访问
    /// - Parameter index: 数组索引
    /// - Returns: 对应的NtkDynamicData值或nil
    public subscript(index: Int) -> NtkDynamicData? {
        guard let array = getArray() else { return nil }
        guard index >= 0 && index < array.count else { return nil }
        return NtkDynamicData.from(array[index])
    }

    /// 支持链式访问的下标方法
    /// 例如: data["user"]["name"] 或 data["items"][0]
    /// - Parameter keyPath: 键路径（字符串或整数）
    /// - Returns: 对应的NtkDynamicData值或nil
    @nonobjc
    public subscript(dynamicMember keyPath: String) -> NtkDynamicData? {
        return self[keyPath]
    }
}

// MARK: - Convenience Navigation

extension NtkDynamicData {

    /// 获取嵌套字典中的值
    /// - Parameter keyPath: 点分隔的键路径，如 "user.profile.name"
    /// - Returns: 对应的NtkDynamicData值或nil
    public func getValue(forKeyPath keyPath: String) -> NtkDynamicData? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: NtkDynamicData? = self

        for key in keys {
            current = current?[key]
            if current == nil {
                return nil
            }
        }

        return current
    }

    /// 获取嵌套数组中的值
    /// - Parameter indexPath: 索引路径数组，如 [0, 1, 2]
    /// - Returns: 对应的NtkDynamicData值或nil
    public func getValue(forIndexPath indexPath: [Int]) -> NtkDynamicData? {
        var current: NtkDynamicData? = self

        for index in indexPath {
            current = current?[index]
            if current == nil {
                return nil
            }
        }

        return current
    }

    /// 安全获取值的便利方法
    /// - Parameters:
    ///   - key: 键名
    ///   - defaultValue: 默认值
    /// - Returns: 获取到的值或默认值
    public func getValue<T>(for key: String, defaultValue: T) -> T {
        guard let value = self[key] else { return defaultValue }
        return (try? value.getValue(as: T.self)) ?? defaultValue
    }

    /// 安全获取数组元素的便利方法
    /// - Parameters:
    ///   - index: 索引
    ///   - defaultValue: 默认值
    /// - Returns: 获取到的值或默认值
    public func getValue<T>(at index: Int, defaultValue: T) -> T {
        guard let value = self[index] else { return defaultValue }
        return (try? value.getValue(as: T.self)) ?? defaultValue
    }
}
