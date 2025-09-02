//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

typealias NtkBool = NtkNetwork<Bool>

/// 网络请求管理器
/// 负责管理网络请求的生命周期，包括请求执行、取消、缓存等功能
/// 支持泛型响应数据类型，提供类型安全的网络请求接口
@NtkActor
public class NtkNetwork<ResponseData: Sendable> {
    
    /// 网络操作对象，封装了请求的具体执行逻辑
    private(set) var operation: NtkOperation
    
    /// 检查当前请求是否已被取消
    public var isCancelled: Bool {
        return !NtkTaskManager.isRequestActive(request: operation.request)
    }
    
    
    /// 初始化网络请求管理器
    /// - Parameters:
    ///   - client: 网络客户端实现
    ///   - request: 网络请求对象
    ///   - dataParsingInterceptor: 响应解析插件
    ///   - validation: 响应验证器
    public required init(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation) {
        operation = NtkOperation(client, request: request, dataParsingInterceptor: dataParsingInterceptor)
        operation.validation = validation
    }
    
    /// 创建网络请求管理器的便捷方法
    /// - Parameters:
    ///   - client: 网络客户端实现
    ///   - request: 网络请求对象
    ///   - dataParsingInterceptor: 响应解析插件
    ///   - validation: 响应验证器
    /// - Returns: 配置好的网络请求管理器实例
    public class func with(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation) -> Self {
        let net = self.init(client, request: request, dataParsingInterceptor: dataParsingInterceptor, validation: validation)
        return net
    }
    
    /// 取消当前请求
    public func cancel() {
        NtkTaskManager.cancelRequest(request: operation.request)
    }
}

extension NtkNetwork {
    
    /// 添加拦截器
    /// - Parameter i: 拦截器实现
    /// - Returns: 当前实例，支持链式调用
    public func addInterceptor(_ i: iNtkInterceptor) -> Self {
        operation.addInterceptor(i)
        return self
    }
    
    /// 设置响应验证器
    /// - Parameter validation: 响应验证实现
    /// - Returns: 当前实例，支持链式调用
    public func validation(_ validation: iNtkResponseValidation) -> Self {
        self.operation.validation = validation
        return self
    }
    
    /// 发送网络请求
    /// 异步执行网络请求并返回响应结果
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 网络响应对象
    /// - Throws: 网络请求过程中的错误
    public func request(storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData> {
        let response: NtkResponse<ResponseData> = try await operation.run(storage)
        return response
    }
    
//    /// 发送网络请求（回调方式）
//    /// 适配Objective-C的闭包回调方式
//    /// - Parameters:
//    ///   - completion: 成功回调
//    ///   - failure: 失败回调
//    public func sendnRequest(_ completion: @escaping (NtkResponse<ResponseData>) -> Void, failure: ((any Error) -> Void)?) {
//        let operation = operation
//        Task {
//            do {
//                let taskManager = NtkTaskManager()
//                let response: NtkResponse<ResponseData> = try await taskManager.executeWithDeduplication(
//                    request: operation.request
//                ) {
//                    try await operation.run()
//                }
//                completion(response)
//            }catch {
//                failure?(error)
//            }
//        }
//    }
    
    
    /// 加载缓存数据
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 缓存的响应对象，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    public func loadCache(storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData>? {
        return try await operation.loadCache(storage)
    }
    
    /// 便捷发起网络请求并加载缓存
    ///
    /// 此方法会同时发起网络请求和加载缓存，并通过异步序列返回结果。
    /// 设计原则是优先显示缓存，网络请求返回后再刷新数据，以优化用户体验。
    ///
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 异步序列，按完成顺序返回缓存和网络响应
    /// - Throws: 在网络请求或缓存加载过程中可能抛出的任何错误
    public func requestWithCache(storage: (any iNtkCacheStorage)? = nil) -> AsyncThrowingStream<NtkResponse<ResponseData>, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var networkReturnedFirst = false
                    try await withThrowingTaskGroup(of: ResponseResult.self) { group in
                        // 并发加载缓存
                        group.addTask {
                            do {
                                return .cache(try await self.loadCache(storage: storage))
                            } catch {
                                print("startWithCache 缓存加载失败，但不影响网络请求: \(error)")
                                return .cache(nil)
                            }
                        }

                        // 并发发起网络请求
                        group.addTask {
                            return .network(try await self.request(storage: storage))
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
    
    /// 响应结果枚举，用于区分缓存和网络响应
    private enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }
}

extension NtkNetwork where ResponseData == Bool {
    /// 判断是否存在缓存数据
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasCacheData(storage: (any iNtkCacheStorage)? = nil) async -> Bool {
        return await operation.hasCacheData(storage)
    }
}
