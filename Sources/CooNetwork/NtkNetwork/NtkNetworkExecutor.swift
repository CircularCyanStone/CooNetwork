//
//  NtkNetworkExecutor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/11.
//

import Foundation

/// 网络请求执行器
/// 负责实际执行网络请求、缓存加载和拦截器链的处理
/// 这是一个内部 Actor，确保执行逻辑的线程安全和隔离
@NtkActor
final class NtkNetworkExecutor<ResponseData: Sendable> {
    
    /// 响应结果枚举，用于区分缓存和网络响应
    private enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }
    
    private let client: any iNtkClient
    private var mutableRequest: NtkMutableRequest
    private let interceptors: [iNtkInterceptor]
    private var coreInterceptors: [iNtkInterceptor]
    private let validation: iNtkResponseValidation
    private let dataParsingInterceptor: iNtkInterceptor
    
    nonisolated
    init(
        client: any iNtkClient,
        request: NtkMutableRequest,
        interceptors: [iNtkInterceptor],
        coreInterceptors: [iNtkInterceptor],
        validation: iNtkResponseValidation,
        dataParsingInterceptor: iNtkInterceptor
    ) {
        self.client = client
        self.mutableRequest = request
        self.interceptors = interceptors
        self.coreInterceptors = coreInterceptors
        self.validation = validation
        self.dataParsingInterceptor = dataParsingInterceptor
    }
    
    // MARK: - Core Execution
    
    func execute() async throws -> NtkResponse<ResponseData> {
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: validation, client: client)
        
        // 动态添加核心拦截器
        var executionCoreInterceptors = coreInterceptors
        executionCoreInterceptors.append(NtkDeduplicationInterceptor())
        executionCoreInterceptors.append(dataParsingInterceptor)
        
        let allInterceptors = interceptors + executionCoreInterceptors.sorted { $0.priority > $1.priority }
        
        let realChainManager = NtkInterceptorChainManager(interceptors: allInterceptors) { [weak self] context in
            // 在执行链末端更新请求对象
            self?.mutableRequest = context.mutableRequest
            let response = try await context.client.execute(context.mutableRequest)
            return response
        }
        
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            } else {
                throw NtkError.serviceDataTypeInvalid
            }
        } catch let error as NtkError {
            throw error
        } catch {
            throw error
        }
    }
    
    func loadCache() async throws -> NtkResponse<ResponseData>? {
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: validation, client: client)
        
        var executionCoreInterceptors = coreInterceptors
        executionCoreInterceptors.append(dataParsingInterceptor)
        let tmpInterceptors = executionCoreInterceptors.sorted { $0.priority > $1.priority }
        
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
            } else {
                throw NtkError.serviceDataTypeInvalid
            }
        } catch NtkError.Cache.noCache {
            return nil
        } catch let error as NtkError {
            throw error
        } catch {
            throw error
        }
    }
    
    func hasCacheData() async -> Bool where ResponseData == Bool {
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: validation, client: client)
        
        // hasCacheData 可能不需要完整的拦截器链，但为了保持一致性，使用已配置的拦截器
        let sortedInterceptors = interceptors.sorted { $0.priority > $1.priority }
        
        let realChainManager = NtkInterceptorChainManager(interceptors: sortedInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            return await context.client.hasCacheData(context.mutableRequest)
        }
        
        do {
            let response = try await realChainManager.execute(context: context) as? NtkResponse<Bool>
            return response?.data ?? false
        } catch {
            return false
        }
    }
    
    // MARK: - Private Helpers
}
