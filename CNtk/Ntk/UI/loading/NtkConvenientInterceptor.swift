//
//  NtkLoadingInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation

/// 便捷拦截器
/// 提供灵活的拦截器构造实现，支持自定义请求前后的处理逻辑
struct NtkConvenientInterceptor: iNtkInterceptor, Sendable {
    
    /// 请求前拦截回调
    /// 在发起网络请求之前执行的回调函数
    var interceptBefore: (@Sendable (_ request: iNtkRequest) -> Void)?
    
    /// 请求后拦截回调
    /// 在网络请求完成后执行的回调函数，无论成功或失败都会调用
    var interceptAfter: (@Sendable (_ request: iNtkRequest, _ response: (any iNtkResponse)?, _ error: (any Error)?) -> Void)?
    
    /// 拦截网络请求
    /// 根据showLoading标志决定是否执行前后拦截逻辑
    /// - Parameters:
    ///   - context: 请求上下文
    ///   - next: 下一个请求处理器
    /// - Returns: 网络响应对象
    /// - Throws: 网络请求过程中的错误
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let requestWrapper = context.client.requestWrapper
        let showLoading = requestWrapper.showLoading
        let request = requestWrapper.request!
        
        let interceptBefore = interceptBefore
        let interceptAfter = interceptAfter
        
        // 如果需要显示加载状态，执行请求前拦截
        if showLoading {
            interceptBefore?(request)
        }
        
        do {
            let response = try await next.handle(context: context)
            // 请求成功，执行请求后拦截
            if showLoading {
                interceptAfter?(request, response, nil)
            }
            return response
        } catch {
            // 请求失败，执行请求后拦截并传递错误
            if showLoading {
                interceptAfter?(request, nil, error)
            }
            throw error
        }
    }
}
