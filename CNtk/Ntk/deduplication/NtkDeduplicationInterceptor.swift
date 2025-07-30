//
//  NtkDeduplicationInterceptor.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求去重拦截器（已弃用）
/// 去重逻辑已完全迁移到 NtkTaskManager 中统一处理，此拦截器仅保留用于向后兼容
/// 建议在未来版本中移除此拦截器，直接使用 NtkTaskManager 的去重功能
@available(*, deprecated, message: "Deduplication logic has been moved to NtkTaskManager. This interceptor will be removed in future versions.")
@NtkActor
class NtkDeduplicationInterceptor: iNtkInterceptor {
    
    /// 拦截器优先级（设置为0，降低优先级）
    var priority: NtkInterceptorPriority {
        return .priority(.low)
    }
    
    /// 单例实例
    static let shared = NtkDeduplicationInterceptor()
    
    private init() {}
    
    /// 拦截请求处理
    /// 直接传递请求，不进行任何处理
    /// - Parameters:
    ///   - context: 请求上下文
    ///   - next: 下一个处理器
    /// - Returns: 网络响应对象
    /// - Throws: 处理过程中的错误
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        // 直接传递给下一个处理器，不进行任何处理
        return try await next.handle(context: context)
    }
}