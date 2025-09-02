//
//  InterceptorChainManager.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

/// 拦截器链管理器
/// 负责将所有拦截器组织成一个链，并启动请求处理
@NtkActor
struct NtkInterceptorChainManager {
    /// 所有注册的拦截器
    private let interceptors: [iNtkInterceptor]
    /// 链的最终处理者（通常是发起实际网络请求的）
    private let finalHandler: @Sendable (NtkInterceptorContext) async throws -> any iNtkResponse

    /// 初始化拦截器链管理器
    /// - Parameters:
    ///   - interceptors: 拦截器数组
    ///   - finalHandler: 最终请求处理器
    init(interceptors: [iNtkInterceptor], finalHandler: @escaping @Sendable (NtkInterceptorContext) async throws -> any iNtkResponse) {
        self.interceptors = interceptors
        self.finalHandler = finalHandler
    }

    /// 执行整个拦截器链的入口方法
    /// - Parameter context: 请求上下文
    /// - Returns: 网络响应对象
    /// - Throws: 执行过程中的错误
    func execute(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        return try await buildChain(index: 0)(context)
    }
    
    /// 构建拦截器链
    /// - Parameter index: 当前拦截器索引
    /// - Returns: 处理函数闭包
    private func buildChain(index: Int) -> @Sendable (NtkInterceptorContext) async throws -> any iNtkResponse {
        if index >= interceptors.count { return finalHandler }
        
        let currentInterceptor = interceptors[index]
        let nextHandler = buildChain(index: index + 1)
        
        return { context in
            // 创建一个临时的处理器来适配拦截器接口
            let tempHandler = TempHandler(handler: nextHandler)
            return try await currentInterceptor.intercept(context: context, next: tempHandler)
        }
    }
    
    /// 临时处理器，用于适配闭包到NtkRequestHandler接口
    private struct TempHandler: NtkRequestHandler {
        let handler: @Sendable (NtkInterceptorContext) async throws -> any iNtkResponse
        
        func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
            return try await handler(context)
        }
    }
}
