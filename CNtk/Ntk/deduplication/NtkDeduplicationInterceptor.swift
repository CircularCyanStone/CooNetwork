//
//  NtkDeduplicationInterceptor.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求去重拦截器
/// 负责检查请求是否启用去重，如果启用则通过 NtkRequestDeduplicationManager 执行请求
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
    /// - Parameters:
    ///   - context: 请求上下文
    ///   - next: 下一个处理器
    /// - Returns: 响应结果
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        // 检查全局去重配置
        guard NtkDeduplicationConfig.shared.isGloballyEnabled else {
            NtkDeduplicationLogger.log("Global deduplication is disabled, skipping")
            return try await next.handle(context: context)
        }
        
        // 检查请求是否启用去重
        let wrapper = context.client.requestWrapper
        guard wrapper.isDeduplicationEnabled else {
            NtkDeduplicationLogger.log("Request deduplication is disabled")
            return try await next.handle(context: context)
        }
        
        // 确保有请求对象
        guard let request = wrapper.request else {
            NtkDeduplicationLogger.log("No request found in wrapper, proceeding without deduplication")
            return try await next.handle(context: context)
        }
        
        NtkDeduplicationLogger.log("Processing request with deduplication: \(request.description)")
        
        // 使用去重管理器执行请求
        return try await NtkRequestDeduplicationManager.shared.executeWithDeduplication(
            request: request
        ) {
            return try await next.handle(context: context)
        }
    }
}