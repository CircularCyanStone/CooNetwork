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
    
    /// 内部类型枚举
    /// 标识状态码的原始数据类型
    private enum `Type`: Int, Sendable {
        case string   // 字符串类型
        case int      // 整数类型
        case bool     // 布尔类型
        case double   // 浮点数类型
        case unknown  // 未知类型
    }
    
    /// 状态码的数据类型
    private let _type: Type?
    
    /// 状态码的原始值
    private let rawValue: Sendable?
    
    /// 编码键枚举
    enum CodingKeys: CodingKey {
        case rawValue
    }
    
    /// 通过值初始化状态码
    /// 根据传入值的类型自动识别并设置内部类型标识
    /// - Parameter value: 状态码值，支持String、Int、Bool、Double类型
    public init(_ value: Sendable?) {
        rawValue = value
        if value is String {
            _type = .string
            return
        }
        if value is Int {
            _type = .int
            return
        }
        
        if value is Bool {
            _type = .bool
            return
        }
        if value is Double {
            _type = .double
            return
        }
        _type = .unknown
    }
    
    /// 从解码器初始化状态码
    /// 尝试按照不同类型顺序解码JSON值，自动识别最合适的类型
    /// - Parameter decoder: JSON解码器
    /// - Throws: 解码过程中的错误
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            rawValue = value
            _type = .string
            return
        }
        
        if let value = try? container.decode(Int.self) {
            rawValue = value
            _type = .int
            return
        }
        
        if let value = try? container.decode(Bool.self) {
            rawValue = value
            _type = .bool
            return
        }
        
        if let value = try? container.decode(Double.self) {
            rawValue = value
            _type = .double
            return
        }
        if container.decodeNil() {
            rawValue = ""
            _type = .string
            return
        }
        _type = .unknown
        rawValue = nil
    }
    
    /// 编码状态码到编码器
    /// 根据内部类型标识将原始值编码为对应的JSON类型
    /// - Parameter encoder: JSON编码器
    /// - Throws: 编码过程中的错误
    public func encode(to encoder: Encoder) throws {
        var singleValueContainer =  encoder.singleValueContainer()
        switch _type {
        case .string:
            try? singleValueContainer.encode(rawValue as! String)
        case .int:
            try? singleValueContainer.encode(rawValue as! Int)
        case .bool:
            try? singleValueContainer.encode(rawValue as! Bool)
        case .double:
            try? singleValueContainer.encode(rawValue as! Double)
        case .unknown:
            try? singleValueContainer.encodeNil()
        case .none:
            try? singleValueContainer.encodeNil()
        }
    }
    
}

// MARK: - 字符串类型访问
extension NtkReturnCode {
    
    /// 获取字符串值（严格类型）
    /// 只有当原始类型为字符串时才返回值，否则返回nil
    /// - Returns: 字符串值或nil
    public var string: String? {
        switch _type {
        case .string:
            return rawValue as? String
        default:
            return nil
        }
    }
    
    /// 获取字符串值（类型转换）
    /// 将任何类型的状态码转换为字符串表示
    /// - Returns: 字符串形式的状态码值
    public var stringValue: String {
        switch _type {
        case .string:
            return rawValue as! String
        case .bool:
            return "\(rawValue!)"
        case .double:
            return "\(rawValue!)"
        case .int:
            return "\(rawValue!)"
        default:
            return ""
        }
    }
    
}

// MARK: - 布尔类型访问
extension NtkReturnCode {
    
    /// 获取布尔值（严格类型）
    /// 只有当原始类型为布尔时才返回值，否则返回nil
    /// - Returns: 布尔值或nil
    public var bool: Bool? {
        switch _type {
        case .bool:
            return rawValue as? Bool
        default:
            return nil
        }
    }
    
    /// 获取布尔值（类型转换）
    /// 将任何类型的状态码转换为布尔值
    /// 字符串：使用NSString的boolValue方法转换
    /// 数字：非零为true，零为false
    /// - Returns: 布尔值
    public var boolValue: Bool {
        switch _type {
        case .string:
            return (rawValue as! NSString).boolValue
        case .bool:
            return rawValue as! Bool
        case .double:
            return (rawValue as! Double) != 0
        case .int:
            return (rawValue as! Int) != 0
        default:
            return false
        }
    }
}

// MARK: - 整数类型访问
extension NtkReturnCode {
    
    /// 获取整数值（严格类型）
    /// 只有当原始类型为整数时才返回值，否则返回nil
    /// - Returns: 整数值或nil
    public var int: Int? {
        switch _type {
        case .int:
            return rawValue as? Int
        default:
            return nil
        }
    }
    
    /// 获取整数值（类型转换）
    /// 将任何类型的状态码转换为整数值
    /// 字符串：使用NSString的integerValue方法转换
    /// 布尔：true为1，false为0
    /// 浮点数：截断小数部分
    /// - Returns: 整数值
    public var intValue: Int {
        switch _type {
        case .string:
            return (rawValue as! NSString).integerValue
        case .bool:
            return (rawValue as! Bool) ? 1 : 0
        case .double:
            return Int(rawValue as! Double)
        case .int:
            return rawValue as! Int
        default:
            return 0
        }
    }
}

// MARK: - 浮点数类型访问
extension NtkReturnCode {
    
    /// 获取浮点数值（严格类型）
    /// 只有当原始类型为浮点数时才返回值，否则返回nil
    /// - Returns: NSNumber包装的浮点数值或nil
    public var double: NSNumber? {
        switch _type {
        case .double:
            return rawValue as? NSNumber
        default:
            return nil
        }
    }
    
    /// 获取浮点数值（类型转换）
    /// 将任何类型的状态码转换为浮点数值
    /// 字符串：尝试解析为浮点数，失败则返回0.0
    /// 布尔：true为1.0，false为0.0
    /// 整数：直接转换为浮点数
    /// - Returns: 浮点数值
    public var doubleValue: Double {
        switch _type {
        case .double:
            return rawValue as! Double
        case .string:
            return Double((rawValue as! String)) ?? 0.0
        case .bool:
            return (rawValue as! Bool) ? 1.0 : 0.0
        case .int:
            return Double(rawValue as! Int)
        default:
            return 0.0
        }
    }
    
}

