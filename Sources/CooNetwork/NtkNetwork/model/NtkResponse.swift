//
//  NtkResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

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
    
    /// 是否来自缓存
    public let isCache: Bool

    /// 初始化网络响应对象
    /// - Parameters:
    ///   - code: 响应状态码
    ///   - data: 响应数据
    ///   - msg: 响应消息
    ///   - response: 原始响应
    ///   - request: 关联的请求
    ///   - isCache: 是否来自缓存
    public init(code: NtkReturnCode, data: ResponseData, msg: String?, response: Sendable, request: iNtkRequest, isCache: Bool) {
        self.code = code
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
        self.isCache = isCache
    }
    
}

