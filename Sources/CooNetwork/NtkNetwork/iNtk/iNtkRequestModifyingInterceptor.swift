//
//  iNtkRequestModifyingInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/07/31.
//

import Foundation

/// 可修改请求的网络拦截器协议。
///
/// `execute()`、`loadCache()` 和 `hasCacheData()` 会分别从初始请求开始，
/// 按拦截器优先级调用 `modifyRequest(_:)`。
public protocol iNtkRequestModifyingInterceptor: iNtkInterceptor {

    /// 修改请求。
    /// - Parameter request: 当前请求快照
    /// - Returns: 修改后的请求快照
    @NtkActor
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest
}

extension iNtkRequestModifyingInterceptor {
    /// 默认透传拦截器链。
    @NtkActor
    public func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
}
