//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation
import NtkNetwork

/// 默认情况下通用的Keys: iNtkResponseMapKeys为RpcResponseMapKeys的Coo的
/// 类型别名
typealias DefaultCoo<ResponseData> = Coo<ResponseData, RpcResponseMapKeys>

/// RPC网络请求管理器
/// 提供RPC请求的便捷创建和配置功能，集成了默认的拦截器和UI交互
///
/// 使用泛型类比泛型方法方便：业务场景里可以直接使用Coo<模型>，也可以在返回值里注明类型。
/// 两者皆可让编译器正常推导泛型类型。
/// 但是如果让with变成泛型方法，则只能通过对返回值注明类型，才能让编译器推导泛型类型。
/// 限定网络请求的逻辑都在@NtkActor隔离域内， 确保不会频繁的出现actor跳跃
@NtkActor
class Coo<ResponseData: Sendable, Keys: iNtkResponseMapKeys> {
    /// 创建RPC网络请求
    /// 自动配置RPC客户端、Loading拦截器和Toast拦截器
    /// - Parameter request: RPC请求对象
    /// - Returns: 配置好的网络请求管理器
    static func with(_ request: iRpcRequest, validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async -> NtkNetwork<ResponseData> {
        
        var _validation: iNtkResponseValidation
        if let requestValidation = request as? iNtkResponseValidation {
            _validation = requestValidation
        }else {
            _validation = validation
        }
        
        let client = RpcClient<Keys>()
        var net = NtkNetwork<ResponseData>.with(client, request: request, dataParsingInterceptor: RpcResponseParsingInterceptor<ResponseData, Keys>(), validation: _validation)
        // 添加loading拦截器
        if let ntkLoadingInterceptor = getLoadingInterceptor(request) {
            // 默认显示loading
            net = net.addInterceptor(ntkLoadingInterceptor)
        }
        net = net.addInterceptor(CooToastInterceptor())
        net = net.addInterceptor(NtkCacheInterceptor())
        return net
    }
}

extension NtkNetwork {
    
    private enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }
    
    /// 便捷发起RPC请求并加载缓存
    ///
    /// 此方法会同时发起网络请求和加载缓存，并通过异步序列返回结果。
    /// 设计原则是优先显示缓存，网络请求返回后再刷新数据，以优化用户体验。
    ///
    /// - Parameters:
    ///   - validation: 响应验证器，默认为 `RpcDetaultResponseValidation`。
    ///
    /// - Throws: 在网络请求或缓存加载过程中可能抛出的任何错误。
    func startRpcWithCache() -> AsyncThrowingStream<NtkResponse<ResponseData>, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var networkReturnedFirst = false
                    try await withThrowingTaskGroup(of: ResponseResult.self) { group in
                        // 并发加载缓存
                        group.addTask {
                            do {
                                return .cache(try await self.loadCache())
                            } catch {
                                print("startRpc 缓存加载失败，但不影响网络请求: \(error)")
                                return .cache(nil)
                            }
                        }

                        // 并发发起网络请求
                        group.addTask {
                            return .network(try await self.sendRequest())
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
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable termination in
                switch termination {
                case .cancelled:
                    // 只有在流被取消时才取消底层任务
                    // 这通常发生在业务层主动取消或者上层作用域被取消
                    print("AsyncStream 被取消，取消底层任务")
                    task.cancel()
                case .finished:
                    // 流正常结束或因错误结束，不需要取消任务
                    // 因为任务要么已经完成，要么已经在 catch 块中处理了错误
                    print("AsyncStream 正常结束，无需取消任务")
                @unknown default:
                    fatalError("unknown")
                }
            }
        }
    }
}
