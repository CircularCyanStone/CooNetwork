//
//  NtkOperation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络操作管理器
/// 负责管理网络请求的执行流程，包括拦截器链、请求处理和响应验证
/// 支持自定义拦截器和核心拦截器的优先级排序
@NtkActor
class NtkOperation {
    
    /// 存储所有注册的自定义拦截器
    private var _interceptors: [iNtkInterceptor] = []
    /// 按优先级排序的自定义拦截器列表
    private(set) var interceptors: [iNtkInterceptor] {
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
    private(set) var coreInterceptors: [iNtkInterceptor] {
        get {
            return _coreInterceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _coreInterceptors = newValue
        }
    }
    
    /// 数据解析插件
    private(set) var dataParsingInterceptor: iNtkInterceptor

    /// 网络客户端实现
    private(set) var client: any iNtkClient
    
    var request: NtkMutableRequest
    
    /// 响应验证器
    var validation: iNtkResponseValidation?
    
    /// 初始化网络操作管理器
    /// - Parameter client: 网络客户端实现
    required
    init(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor) {
        self.client = client
        self.client.storage.addRequest(request)
        self.request = NtkMutableRequest(request)
        self.dataParsingInterceptor = dataParsingInterceptor
        embededCoreInterceptor()
    }
    
    /// 添加核心拦截器
    /// - Parameter i: 拦截器实现
    private func addCoreInterceptor(_ i: iNtkInterceptor) {
        _coreInterceptors.append(i)
    }
    
    /// 嵌入核心拦截器
    /// 自动添加必要的核心拦截器，如验证拦截器
    private func embededCoreInterceptor() {
        addCoreInterceptor(NtkValidationInterceptor())
    }
}

extension NtkOperation {
    
    /// 添加自定义拦截器
    /// - Parameter i: 拦截器实现
    func addInterceptor(_ i: iNtkInterceptor) {
        _interceptors.append(i)
    }
    
    /// 配置网络请求
    /// 将请求添加到请求包装器和缓存存储中
    /// - Parameter request: 网络请求对象
    private func with(_ request: iNtkRequest) {
        
    }
    
    /// 执行网络请求
    /// 通过拦截器链处理请求，最终调用API请求处理器
    /// - Returns: 类型化的网络响应对象
    /// - Throws: 网络请求过程中的错误
    func run<ResponseData>(_ storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData> {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        if let storage {
            client.storage = storage
        }
        let context = NtkInterceptorContext(mutableRequest: request, validation: validation, client: client)
        
        addCoreInterceptor(NtkDeduplicationInterceptor())
        addCoreInterceptor(dataParsingInterceptor)
        let tmpInterceptors =  interceptors + coreInterceptors
        
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { context in
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
    func loadCache<ResponseData>(_ storage: (any iNtkCacheStorage)? = nil) async throws -> NtkResponse<ResponseData>? {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        if let storage {
            client.storage = storage
        }
        let context = NtkInterceptorContext(mutableRequest: request, validation: validation, client: client)
        
        addCoreInterceptor(dataParsingInterceptor)
        let tmpInterceptors = coreInterceptors
        // 缓存直接进行最终读取缓存解析处理
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { context in
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
    
    /// 检查是否有缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    func hasCacheData(_ storage: (any iNtkCacheStorage)? = nil) async -> Bool {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        if let storage {
            client.storage = storage
        }
        let context = NtkInterceptorContext(mutableRequest: request, validation: validation, client: client)
        
        let realChainManager = NtkInterceptorChainManager(interceptors: interceptors) { context in
            await context.client.hasCacheData(context.mutableRequest)
        }
        do {
            let response = try await realChainManager.execute(context: context) as? NtkResponse<Bool>
            return response?.data ?? false
        }catch {
            return false
        }
    }
}
