//
//  NtkOperation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

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

    /// 网络客户端实现
    private(set) var client: any iNtkClient
    
    /// 请求包装器，代理到客户端的请求包装器
    var requestWrapper: NtkRequestWrapper {
        get {
            client.requestWrapper
        }
        set {
            client.requestWrapper = newValue
        }
    }
    
    /// 响应验证器
    var validation: iNtkResponseValidation?
    
    /// 初始化网络操作管理器
    /// - Parameter client: 网络客户端实现
    required
    init(_ client: any iNtkClient) {
        self.client = client
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
    func with(_ request: iNtkRequest) {
        client.requestWrapper.addRequest(request)
        client.storage.addRequest(request)
    }
    
    /// 执行网络请求
    /// 通过拦截器链处理请求，最终调用API请求处理器
    /// - Returns: 类型化的网络响应对象
    /// - Throws: 网络请求过程中的错误
    func run<ResponseData>() async throws -> NtkResponse<ResponseData> {
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        let context = NtkRequestContext(validation: validation, client: client)
        
        let tmpInterceptors =  interceptors + coreInterceptors
        let realApiHandle: NtkDefaultApiRequestHandler<ResponseData> = NtkDefaultApiRequestHandler()
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors, finalHandler: realApiHandle)
        
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
    func loadCache<ResponseData>() async throws -> NtkResponse<ResponseData>? {
        guard client.requestWrapper.request != nil else {
            fatalError("request must not be nil")
        }
        guard let validation else {
            fatalError("iNtkResponseValidation must not be nil, you should call method 'func validation(_ validation: iNtkResponseValidation) -> Self' first")
        }
        let context = NtkRequestContext(validation: validation, client: client)
        let realApiHandle: NtkDefaultCacheRequestHandler<ResponseData> = NtkDefaultCacheRequestHandler()
        
        // 缓存直接进行最终读取缓存解析处理
        let realChainManager = NtkInterceptorChainManager(interceptors: coreInterceptors, finalHandler: realApiHandle)
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
}
