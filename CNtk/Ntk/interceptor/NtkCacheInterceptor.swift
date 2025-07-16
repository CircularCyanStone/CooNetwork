//
//  NtkCacheInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/15.
//
// 默认的请求缓存工具
// 拦截器
import Foundation

struct NtkDefaultCacheInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority {
        .priority(0)
    }
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        // 能走到这里说明已经通过了NtkValidationInterceptor的校验
        guard let request = context.client.requestWrapper.request else { return response }
        if request.cacheTime > 0 && request.customPolicy(response) {
            
        }
        return response
    }
}
