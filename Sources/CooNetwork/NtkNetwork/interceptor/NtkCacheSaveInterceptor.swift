//
//  NtkCacheInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/15.
//

/// 默认缓存拦截器
/// 负责处理网络请求的缓存逻辑，在响应验证通过后执行缓存操作
import Foundation

/// 响应提取器闭包类型，用于从不同类型的响应中提取数据
public typealias ResponseExtractor = @Sendable (any iNtkResponse) -> Sendable?

/// 默认缓存拦截器实现
/// 提供基础的响应缓存功能，支持自定义缓存策略
public struct NtkCacheSaveInterceptor: iNtkInterceptor {
    /// 拦截器优先级
    /// 使用最低优先级（0），确保在所有其他拦截器之后执行
    public var priority: NtkInterceptorPriority
    
    /// 响应提取器，用于从响应中提取需要缓存的数据
    private let responseExtractor: ResponseExtractor
    
    /// 默认初始化方法，使用默认的响应提取器
    public init(priority: NtkInterceptorPriority = .priority(0)) {
        self.priority = priority
        self.responseExtractor = Self.defaultResponseExtractor
    }
    
    /// 自定义初始化方法，允许传入自定义的响应提取器
    /// - Parameters:
    ///   - priority: 拦截器优先级
    ///   - responseExtractor: 自定义的响应提取器闭包
    public init(priority: NtkInterceptorPriority = .priority(0), responseExtractor: @escaping ResponseExtractor) {
        self.priority = priority
        self.responseExtractor = responseExtractor
    }
    
    /// 默认的响应提取器实现，保持原有的response.response转换逻辑
    /// - Parameter response: 响应对象
    /// - Returns: 提取的响应数据，如果无法提取则返回nil
    private static func defaultResponseExtractor(_ response: any iNtkResponse) -> Sendable? {
        return response.response
    }
    /// 拦截并处理缓存
    /// - Parameters:
    ///   - context: 请求上下文
    ///   - next: 下一个请求处理器
    /// - Returns: 处理后的响应对象
    /// - Throws: 处理过程中的错误
    public func intercept(context: NtkInterceptorContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        // 能走到这里说明已经通过了NtkValidationInterceptor的校验
        guard let requestPolicy = context.mutableRequest.requestConfiguration else { return response }
        if requestPolicy.cacheTime > 0 && requestPolicy.shouldCache(response) {
            // 根据缓存时间和自定义策略保存响应到缓存
            if let extractedResponse = responseExtractor(response) {
                let result = await context.client.saveCache(context.mutableRequest, response: extractedResponse)
                NtkLogger.shared.debug("NTK请求缓存\(result ? "成功" : "失败")")
            }
        }
        return response
    }
}
