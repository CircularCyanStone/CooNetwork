//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络组件错误类型
/// 定义了网络请求过程中可能出现的各种错误情况
public enum NtkError: Error {
    
    /// 服务端业务逻辑验证失败
    /// 当响应验证器判断服务端返回的业务状态码表示失败时抛出
    case validation(_ request: iNtkRequest, _ response: any iNtkResponse)
    
    /// JSON数据无效
    /// 当接口返回的数据不是有效的JSON格式时抛出
    case jsonInvalid(_ request: iNtkRequest, _ response: Sendable)
    
    /// JSON解码错误
    /// 当使用JSONDecoder解码数据为模型时发生错误
    case decodeInvalid(_ error: Error, _ response: Sendable, _ request: iNtkRequest? = nil)
    
    /// 服务端数据为空
    /// 当服务端返回的JSON中data字段为空时抛出
    case serviceDataEmpty
    
    /// 服务端数据类型不匹配
    /// 当服务端返回的data字段类型与期望的泛型类型不匹配时抛出
    case serviceDataTypeInvalid
    
    /// 请求结果类型不匹配
    /// 当请求返回的结果类型与期望类型不匹配时抛出
    case typeMismatch
    
    /// 请求已被取消
    /// 当请求在执行过程中被主动取消时抛出
    case requestCancelled
    
    /// 请求超时
    /// 当请求执行时间超过设定的超时时间时抛出
    case requestTimeout
    
    /// 其他类型错误（包括系统URLError）
    /// 包装其他未分类的错误
    case other(_ error: Error)
    
    /// 缓存相关错误
    enum Cache: Error {
        /// 没有缓存数据
        case noCache
    }
    
}
