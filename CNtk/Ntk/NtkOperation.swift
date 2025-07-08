//
//  NtkOperation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

@objcMembers
class NtkOperation: NSObject {
    
    // 存储所有注册的拦截器
    private var _interceptors: [iNtkInterceptor] = []
    private(set) var interceptors: [iNtkInterceptor] {
        get {
            return _interceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _interceptors = newValue
        }
    }
    
    private var _coreInterceptors: [iNtkInterceptor] = []
    private(set) var coreInterceptors: [iNtkInterceptor] {
        get {
            return _coreInterceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _coreInterceptors = newValue
        }
    }

    private(set) var client: any iNtkClient
    
    var validation: iNtkResponseValidation?
    
    required
    init(_ client: any iNtkClient) {
        self.client = client
        super.init()
        embededCoreInterceptor()
    }
    
    private func addCoreInterceptor(_ i: iNtkInterceptor) {
        _coreInterceptors.append(i)
    }
    
    private func embededCoreInterceptor() {
        addCoreInterceptor(NtkValidationInterceptor())
    }
}

extension NtkOperation {
    
    func addInterceptor(_ i: iNtkInterceptor) {
        _interceptors.append(i)
    }
    
    func run<ResponseData>() async throws -> NtkResponse<ResponseData> {
        assert(validation != nil, "")
        let context = NtkRequestContext(validation: validation!, client: client)
        let tmpInterceptors =  interceptors + coreInterceptors
        let realApiHandle: NtkDefaultApiRequestHandler<ResponseData> = NtkDefaultApiRequestHandler()
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors, finalHandler: realApiHandle)
        
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            }else {
                throw NtkError.responseDataTypeError
            }
        }catch let error as NtkError {
            throw error
        }catch {
            throw error
        }
    }
    
    /// 加载缓存
    /// - Parameter storage: 缓存加载工具
    /// - Returns: 结果
    func loadCache<ResponseData>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        let context = NtkRequestContext(validation: validation!, client: client)
        let realApiHandle: NtkDefaultCacheRequestHandler<ResponseData> = NtkDefaultCacheRequestHandler()
        
        // 缓存直接进行最终读取缓存解析处理
        let realChainManager = NtkInterceptorChainManager(interceptors: [], finalHandler: realApiHandle)
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            }else {
                throw NtkError.responseDataTypeError
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
