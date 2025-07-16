//
//  NtkCacheInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/15.
//
/// 默认缓存拦截器
/// 负责处理网络请求的缓存逻辑，在响应验证通过后执行缓存操作
import Foundation

/// 默认缓存拦截器实现
/// 提供基础的响应缓存功能，支持自定义缓存策略
struct NtkDefaultCacheInterceptor: iNtkInterceptor {
    /// 拦截器优先级
    /// 使用最低优先级（0），确保在所有其他拦截器之后执行
    var priority: NtkInterceptorPriority {
        .priority(0)
    }
    
    /// 拦截并处理缓存
    /// - Parameters:
    ///   - context: 请求上下文
    ///   - next: 下一个请求处理器
    /// - Returns: 处理后的响应对象
    /// - Throws: 处理过程中的错误
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        // 能走到这里说明已经通过了NtkValidationInterceptor的校验
        guard let request = context.client.requestWrapper.request, let cachePolicy = request.cachePolicy else { return response }
         if cachePolicy.cacheTime > 0 && cachePolicy.customPolicy(response) {
             // 根据缓存时间和自定义策略保存响应到缓存
             let result = await context.client.saveCache(response)
             print("NTK请求缓存\(result ? "成功" : "失败")")
         }
        return response
    }
}
