//
//  NtkValidationInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 响应验证拦截器
/// 负责验证服务端响应的有效性，确保业务逻辑正确性
struct NtkValidationInterceptor: iNtkInterceptor {
    /// 拦截器优先级
    /// 使用高优先级确保在其他拦截器之后执行验证
    var priority: NtkInterceptorPriority {
        .priority(.high)
    }
    
    /// 拦截并验证响应
    /// - Parameters:
    ///   - context: 请求上下文，包含验证器
    ///   - next: 下一个请求处理器
    /// - Returns: 验证通过的响应对象
    /// - Throws: 验证失败时抛出NtkError.validation错误
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        let serviceOK = context.validation.isServiceSuccess(response)
        if serviceOK {
            /// 服务端校验通过，返回响应
            return response
        }else {
            /// 服务端校验失败，抛出验证错误
            throw NtkError.validation(response.request, response)
        }
    }
}
