//
//  NtkDeduplicationInterceptor.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求去重拦截器
/// 去重拦截器（已简化）
/// 去重逻辑已在 NtkNetwork 层面通过 NtkTaskManager 统一处理
/// 优先级较高，确保在其他拦截器之前执行
@NtkActor
class NtkDeduplicationInterceptor: iNtkInterceptor {
    
    /// 拦截器优先级 - 高优先级确保在其他拦截器之前执行
    var priority: NtkInterceptorPriority {
        return .priority(.high)
    }
    
    /// 单例实例
    static let shared = NtkDeduplicationInterceptor()
    
    private init() {}
    
    /// 拦截请求并处理去重逻辑
    /// 注意：去重逻辑已在NtkNetwork层面统一处理，此拦截器主要用于兼容性
    /// - Parameters:
    ///   - context: 请求上下文
    ///   - next: 下一个处理器
    /// - Returns: 响应结果
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        // 直接传递给下一个处理器，去重逻辑已在NtkNetwork层面处理
        return try await next.handle(context: context)
    }
}