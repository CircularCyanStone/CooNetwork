//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

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
    public func sendRequest(storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData> {
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
    
    /// 判断是否存在缓存数据
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasCacheData(storage: (any iNtkCacheStorage)? = nil) async -> Bool {
        return await operation.hasCacheData(storage)
    }
}
