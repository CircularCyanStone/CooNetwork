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
    
    /// 响应结果枚举，用于区分缓存和网络响应
    private enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }
    
    /// 网络客户端实现
    private var client: any iNtkClient
    
    /// 数据解析插件
    private var dataParsingInterceptor: iNtkInterceptor

    private var mutableRequest: NtkMutableRequest
    
    /// 响应验证器
    private var validation: iNtkResponseValidation?
    
    /// 存储所有注册的自定义拦截器
    private var _interceptors: [iNtkInterceptor] = []
    /// 按优先级排序的自定义拦截器列表
    private var interceptors: [iNtkInterceptor] {
        get {
            return _interceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _interceptors = newValue
        }
    }
    
    /// 存储所有核心拦截器
    private var _coreInterceptors: [iNtkInterceptor] = []
    /// 按优先级排序的核心拦截器列表
    private var coreInterceptors: [iNtkInterceptor] {
        get {
            return _coreInterceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _coreInterceptors = newValue
        }
    }
    
    /// 检查当前请求是否已被取消
    public var isCancelled: Bool {
        return !NtkTaskManager.isRequestActive(request: mutableRequest)
    }
    
    
    /// 初始化网络请求管理器
    /// - Parameters:
    ///   - client: 网络客户端实现
    ///   - request: 网络请求对象
    ///   - dataParsingInterceptor: 响应解析插件
    ///   - validation: 响应验证器
    public required init(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation) {
        self.client = client
        self.mutableRequest = NtkMutableRequest(request)
        self.dataParsingInterceptor = dataParsingInterceptor
        self.validation = validation
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
    
}
private extension NtkNetwork {
    /// 添加核心拦截器
    /// - Parameter i: 拦截器实现
    func addCoreInterceptor(_ i: iNtkInterceptor) {
        _coreInterceptors.append(i)
    }
    
}

extension NtkNetwork {
    
    /// 添加拦截器
    /// - Parameter i: 拦截器实现
    /// - Returns: 当前实例，支持链式调用
    @discardableResult
    public func addInterceptor(_ i: iNtkInterceptor) -> Self {
        _interceptors.append(i)
        return self
    }
    
    /// 设置响应验证器
    /// - Parameter validation: 响应验证实现
    /// - Returns: 当前实例，支持链式调用
    @discardableResult
    public func validation(_ validation: iNtkResponseValidation) -> Self {
        self.validation = validation
        return self
    }
    
    /// 取消当前请求
    public func cancel() {
        NtkTaskManager.cancelRequest(request: mutableRequest)
    }
    
    
    
    public func setRequestValue(_ value: Sendable, forKey key: String) {
        mutableRequest[key] = value
    }
    
    /// 发送网络请求
    /// 异步执行网络请求并返回响应结果
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 网络响应对象
    /// - Throws: 网络请求过程中的错误
    @discardableResult
    public func request(storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData> {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        if let storage {
            client.storage = storage
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: validation, client: client)
        
        addCoreInterceptor(NtkDeduplicationInterceptor())
        addCoreInterceptor(dataParsingInterceptor)
        let tmpInterceptors =  interceptors + coreInterceptors
        
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            let response = try await context.client.execute(context.mutableRequest)
            return response
        }
        
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            }else {
                throw NtkError.serviceDataTypeInvalid
            }
        }catch let error as NtkError {
            throw error
        }catch {
            throw error
        }
    }
    
    /// 加载缓存数据
    /// 直接通过缓存请求处理器读取缓存，跳过拦截器链
    /// - Returns: 缓存的响应对象，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    public func loadCache(storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData>? {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        if let storage {
            client.storage = storage
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: validation, client: client)
        
        addCoreInterceptor(dataParsingInterceptor)
        let tmpInterceptors = coreInterceptors
        // 缓存直接进行最终读取缓存解析处理
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            if let response = try await context.client.loadCache(context.mutableRequest) {
                return response
            }
            throw NtkError.Cache.noCache
        }
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            }else {
                throw NtkError.serviceDataTypeInvalid
            }
        }catch NtkError.Cache.noCache {
            return nil
        }catch let error as NtkError {
            throw error
        }catch {
            throw error
        }
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
    
}

extension NtkNetwork where ResponseData == Bool {
    /// 判断是否存在缓存数据
    /// - Parameter storage: 网络请求缓存存储工具
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasCacheData(storage: (any iNtkCacheStorage)? = nil) async -> Bool {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        if let storage {
            client.storage = storage
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: validation, client: client)
        
        let realChainManager = NtkInterceptorChainManager(interceptors: interceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            return await context.client.hasCacheData(context.mutableRequest)
        }
        do {
            let response = try await realChainManager.execute(context: context) as? NtkResponse<Bool>
            return response?.data ?? false
        }catch {
            return false
        }
    }
}
