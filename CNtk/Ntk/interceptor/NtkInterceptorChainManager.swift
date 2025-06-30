//
//  InterceptorChainManager.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

// 负责将所有拦截器组织成一个链，并启动请求处理
class NtkInterceptorChainManager {
    // 所有注册的拦截器
    private let interceptors: [iNtkInterceptor]
    // 链的最终处理者（通常是发起实际网络请求的）
    private let finalHandler: NtkRequestHandler

    init(interceptors: [iNtkInterceptor], finalHandler: NtkRequestHandler) {
        self.interceptors = interceptors
        self.finalHandler = finalHandler
    }

    // 执行整个拦截器链的入口方法
    func execute(context: NtkRequestContext) async throws -> any iNtkResponse {
        // 核心：构建链。我们从链的末端（finalHandler）开始，逆序地将拦截器层层包裹。
        // 这使得在执行时，请求会从第一个拦截器开始，依次深入到最终的Handler。
        var currentHandler: NtkRequestHandler = finalHandler

        // 逆序遍历拦截器列表，因为每个拦截器都需要“包裹”它后面的处理逻辑
        for interceptor in interceptors.reversed() {
            // 每一步都创建一个“适配器”，它将当前拦截器和链的剩余部分（currentHandler）连接起来
            currentHandler = InterceptorHandlerAdapter(interceptor: interceptor, next: currentHandler)
        }
        // 启动执行：调用最外层（第一个）拦截器的 handle 方法
        return try await currentHandler.handle(context: context)
    }
}

fileprivate class InterceptorHandlerAdapter: NtkRequestHandler {
    private let interceptor: iNtkInterceptor
    private let next: NtkRequestHandler

    init(interceptor: iNtkInterceptor, next: NtkRequestHandler) {
        self.interceptor = interceptor
        self.next = next
    }
    func handle(context: NtkRequestContext) async throws -> any iNtkResponse {
        return try await interceptor.intercept(context: context, next: self.next)
    }
}
