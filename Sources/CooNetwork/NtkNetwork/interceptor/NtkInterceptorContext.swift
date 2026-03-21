//
//  NtkInterceptorContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 拦截器上下文
/// 在拦截器链中传递，携带请求、验证器、客户端等共享信息
@NtkActor
public final class NtkInterceptorContext: Sendable {

    /// 可修改的请求对象
    public var mutableRequest: NtkMutableRequest

    /// 响应验证器
    public let validation: iNtkResponseValidation

    /// 网络客户端
    public let client: any iNtkClient

    /// 可缓存的客户端（可选）
    /// 只有当 client 同时遵循 iNtkCacheableClient 时才有值
    public let cacheableClient: (any iNtkCacheableClient)?

    /// 拦截器间传递的额外数据
    public var extraData: [String: Sendable] = [:]

    init(mutableRequest: NtkMutableRequest, validation: iNtkResponseValidation, client: any iNtkClient, cacheableClient: (any iNtkCacheableClient)? = nil) {
        self.mutableRequest = mutableRequest
        self.validation = validation
        self.client = client
        self.cacheableClient = cacheableClient
    }
}
