//
//  NtkResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 响应键映射协议
/// 定义了服务端响应JSON中各个字段的键名映射
public protocol iNtkResponseMapKeys {
    /// 状态码字段的键名
    static var code: String { get }
    /// 数据字段的键名
    static var data: String { get }
    /// 消息字段的键名
    static var msg: String { get }
}


/// 网络组件编码键
/// 实现CodingKey协议，支持动态键名的JSON解码
public struct NtkCodingKeys: CodingKey {
    /// 字符串形式的键值
    public let stringValue: String
    
    /// 整数形式的键值（可选）
    public let intValue: Int?
    
    /// 通过字符串初始化编码键
    /// - Parameter stringValue: 字符串键值
    public init?(stringValue: String) {
        self.stringValue = stringValue
        if let intValue = Int(stringValue) {
            self.intValue = intValue
        }else {
            self.intValue = nil
        }
    }
    
    /// 通过整数初始化编码键
    /// - Parameter intValue: 整数键值
    public init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    /// 通过其他CodingKey初始化
    /// - Parameter base: 基础编码键
    public init<Key>(_ base: Key) where Key: CodingKey {
        if let intValue = base.intValue {
            self.init(intValue: intValue)!
        } else {
            self.init(stringValue: base.stringValue)!
        }
    }
}

/// 网络响应解码器
/// 用于将JSON响应数据解码为结构化的响应对象
public struct NtkResponseDecoder<ResponseData: Decodable, Keys: iNtkResponseMapKeys>: Decodable {
    
    /// 响应状态码
    public let code: NtkReturnCode
    
    /// 响应数据（可选）
    /// 设置为可选是为了避免后端数据不存在、类型不匹配或为Null时导致崩溃
    /// 后续交由开发者手动处理data为nil的情况
    public let data: ResponseData?
    
    /// 响应消息（可选）
    public let msg: String?
    
    /// 从解码器初始化响应对象
    /// - Parameter decoder: JSON解码器
    /// - Throws: 解码过程中的错误
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: NtkCodingKeys.self)
        
        let codeKey = NtkCodingKeys(stringValue: Keys.code)!
        self.code = try container.decode(NtkReturnCode.self, forKey: codeKey)
        
        let dataKey = NtkCodingKeys(stringValue: Keys.data)!
        self.data = try container.decodeIfPresent(ResponseData.self, forKey: dataKey)
        
        let msgKey = NtkCodingKeys(stringValue: Keys.msg)!
        self.msg = try container.decodeIfPresent(String.self, forKey: msgKey)
    }
}


/// 网络响应对象
/// 用于在抽象协议中使用的具体响应实现
/// 避免了NtkResponseDecoder中泛型Keys在抽象协议中被要求的问题
public struct NtkResponse<ResponseData: Sendable>: iNtkResponse, Sendable {
    
    /// 响应状态码
    public let code: NtkReturnCode
    
    /// 响应数据
    public let data: ResponseData
    
    /// 响应消息（可选）
    public let msg: String?
    
    /// 原始响应数据
    public let response: Sendable
    
    /// 关联的请求对象
    public let request: iNtkRequest
    
    public let isCache: Bool
    
    public init(code: NtkReturnCode, data: ResponseData, msg: String?, response: Sendable, request: iNtkRequest, isCache: Bool) {
        self.code = code
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
        self.isCache = isCache
    }
    
}

