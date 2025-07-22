//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation


/// 使用默认RpcResponseMapKeys的Coo类型别名
typealias DefaultCoo = Coo<RpcResponseMapKeys>

/// RPC网络请求管理器
/// 提供RPC请求的便捷创建和配置功能，集成了默认的拦截器和UI交互
class Coo<Keys: NtkResponseMapKeys> {
    /// 创建RPC网络请求
    /// 自动配置RPC客户端、Loading拦截器和Toast拦截器
    /// - Parameter request: RPC请求对象
    /// - Returns: 配置好的网络请求管理器
    static func with<ResponseData>(_ request: iRpcRequest) async -> NtkNetwork<ResponseData> {
        let client = RpcClient<Keys>()
        var net = await NtkNetwork<ResponseData>.with(request, client: client)
        // 添加loading拦截器
        if let ntkLoadingInterceptor = getLoadingInterceptor(request) {
            // 默认显示loading
            net = await net.addInterceptor(ntkLoadingInterceptor).hud(true)
        }
        net = await net.addInterceptor(CooToastInterceptor())
        net = await net.addInterceptor(NtkDefaultCacheInterceptor())
        return net
    }
}

extension NtkNetwork {
    
    /// RPC便捷发起请求方法
    /// 使用默认的RPC响应验证器发起网络请求
    /// - Parameter validation: 响应验证器，默认使用RpcDetaultResponseValidation
    /// - Returns: 网络响应对象
    /// - Throws: 网络请求过程中的错误
    func startRpc(_ validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async throws -> NtkResponse<ResponseData> {
        return try await self.validation(validation).sendRequest()
    }
    
    func loadRpcCache(_ validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async throws -> NtkResponse<ResponseData>? {
        return try await self.validation(validation).loadCache()
    }
    
    /// 便捷发起RPC请求并加载缓存
    ///
    /// 此方法会同时发起网络请求和加载缓存，并通过回调分别返回结果。
    /// 设计原则是优先显示缓存，网络请求返回后再刷新数据，以优化用户体验。
    ///
    /// - Parameters:
    ///   - validation: 响应验证器，默认为 `RpcDetaultResponseValidation`。
    ///   - responseBlock: 一个闭包，用于接收和处理网络响应。该闭包可能会被调用两次：
    ///                  第一次是缓存加载完成时，第二次是网络请求成功时。
    ///
    /// - Throws: 在网络请求或缓存加载过程中可能抛出的任何错误。
    private enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }
    
    func startRpcWithCache(
        _ validation: iNtkResponseValidation = RpcDetaultResponseValidation()
    ) -> AsyncThrowingStream<NtkResponse<ResponseData>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var networkReturnedFirst = false
                try await withThrowingTaskGroup(of: ResponseResult.self) { group in
                    // 并发加载缓存
                    group.addTask {
                        .cache(try await self.loadRpcCache(validation))
                    }

                    // 并发发起网络请求
                    group.addTask {
                        .network(try await self.startRpc(validation))
                    }

                    // 按完成顺序处理结果
                    for try await result in group {
                        switch result {
                        case .network(let response):
                            networkReturnedFirst = true
                            continuation.yield(response)
                            // 网络请求成功后，可以取消其他任务并提前结束
                            group.cancelAll()
                        case .cache(let response):
                            if !networkReturnedFirst, let response = response {
                                continuation.yield(response)
                            }
                        }
                    }
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
