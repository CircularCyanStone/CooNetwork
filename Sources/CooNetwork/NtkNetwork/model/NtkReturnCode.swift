//
//  NtkReturnCode.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络响应状态码包装器
/// 支持多种数据类型的状态码（字符串、整数、布尔值、浮点数）
/// 提供类型安全的访问方式和自动类型转换功能
public final class NtkReturnCode: Codable, Sendable {
    
    /// 内部存储枚举
    /// 将类型标记与值绑定在一起，确保类型与值始终一致
    private enum Storage: Sendable {
        case string(String)
        case int(Int)
        case bool(Bool)
        case double(Double)
        case unknown
    }

    /// 状态码的内部存储
    private let storage: Storage
    
    /// 通过值初始化状态码
    /// 根据传入值的类型自动识别并设置内部类型标识
    /// - Parameter value: 状态码值，支持String、Int、Bool、Double类型
    public init(_ value: Sendable?) {
        if let v = value as? String {
            storage = .string(v)
        } else if let v = value as? Int {
            storage = .int(v)
        } else if let v = value as? Bool {
            storage = .bool(v)
        } else if let v = value as? Double {
            storage = .double(v)
        } else {
            storage = .unknown
        }
    }
    
    /// 从解码器初始化状态码
    /// 尝试按照不同类型顺序解码JSON值，自动识别最合适的类型
    /// - Parameter decoder: JSON解码器
    /// - Throws: 解码过程中的错误
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            storage = .string(value)
        } else if let value = try? container.decode(Int.self) {
            storage = .int(value)
        } else if let value = try? container.decode(Bool.self) {
            storage = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            storage = .double(value)
        } else if container.decodeNil() {
            storage = .string("")
        } else {
            storage = .unknown
        }
    }
    
    /// 编码状态码到编码器
    /// 根据内部类型标识将原始值编码为对应的JSON类型
    /// - Parameter encoder: JSON编码器
    /// - Throws: 编码过程中的错误
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch storage {
        case .string(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .bool(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .unknown:
            try container.encodeNil()
        }
    }
    
}

// MARK: - 字符串类型访问
extension NtkReturnCode {
    
    /// 获取字符串值（严格类型）
    /// 只有当原始类型为字符串时才返回值，否则返回nil
    /// - Returns: 字符串值或nil
    public var string: String? {
        if case .string(let v) = storage { return v }
        return nil
    }

    /// 获取字符串值（类型转换）
    /// 将任何类型的状态码转换为字符串表示
    /// - Returns: 字符串形式的状态码值
    public var stringValue: String {
        switch storage {
        case .string(let v): return v
        case .int(let v):    return "\(v)"
        case .bool(let v):   return "\(v)"
        case .double(let v): return "\(v)"
        case .unknown:       return ""
        }
    }
    
}

// MARK: - 布尔类型访问
extension NtkReturnCode {
    
    /// 获取布尔值（严格类型）
    /// 只有当原始类型为布尔时才返回值，否则返回nil
    /// - Returns: 布尔值或nil
    public var bool: Bool? {
        if case .bool(let v) = storage { return v }
        return nil
    }

    /// 获取布尔值（类型转换）
    /// 将任何类型的状态码转换为布尔值
    /// 字符串：使用NSString的boolValue方法转换
    /// 数字：非零为true，零为false
    /// - Returns: 布尔值
    public var boolValue: Bool {
        switch storage {
        case .string(let v): return (v as NSString).boolValue
        case .bool(let v):   return v
        case .double(let v): return v != 0
        case .int(let v):    return v != 0
        case .unknown:       return false
        }
    }
}

// MARK: - 整数类型访问
extension NtkReturnCode {
    
    /// 获取整数值（严格类型）
    /// 只有当原始类型为整数时才返回值，否则返回nil
    /// - Returns: 整数值或nil
    public var int: Int? {
        if case .int(let v) = storage { return v }
        return nil
    }

    /// 获取整数值（类型转换）
    /// 将任何类型的状态码转换为整数值
    /// 字符串：使用NSString的integerValue方法转换
    /// 布尔：true为1，false为0
    /// 浮点数：截断小数部分
    /// - Returns: 整数值
    public var intValue: Int {
        switch storage {
        case .string(let v): return (v as NSString).integerValue
        case .bool(let v):   return v ? 1 : 0
        case .double(let v): return Int(v)
        case .int(let v):    return v
        case .unknown:       return 0
        }
    }
}

// MARK: - 浮点数类型访问
extension NtkReturnCode {
    
    /// 获取浮点数值（严格类型）
    /// 只有当原始类型为浮点数时才返回值，否则返回nil
    /// - Returns: NSNumber包装的浮点数值或nil
    public var double: NSNumber? {
        if case .double(let v) = storage { return v as NSNumber }
        return nil
    }

    /// 获取浮点数值（类型转换）
    /// 将任何类型的状态码转换为浮点数值
    /// 字符串：尝试解析为浮点数，失败则返回0.0
    /// 布尔：true为1.0，false为0.0
    /// 整数：直接转换为浮点数
    /// - Returns: 浮点数值
    public var doubleValue: Double {
        switch storage {
        case .double(let v): return v
        case .string(let v): return Double(v) ?? 0.0
        case .bool(let v):   return v ? 1.0 : 0.0
        case .int(let v):    return Double(v)
        case .unknown:       return 0.0
        }
    }
    
}

