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
    enum ResponseResult {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }

    /// 执行器配置快照
    /// 由 NtkNetwork 在 getOrCreateExecutor() 时冻结，执行期间不可变
    struct Configuration {
        let client: any iNtkClient
        let cacheableClient: (any iNtkCacheableClient)?
        let request: NtkMutableRequest
        let interceptors: [iNtkInterceptor]
        var coreInterceptors: [iNtkInterceptor]
        let validation: iNtkResponseValidation
        let dataParsingInterceptor: iNtkInterceptor
    }

    private let config: Configuration
    private var mutableRequest: NtkMutableRequest

    nonisolated
    init(config: Configuration) {
        self.config = config
        self.mutableRequest = config.request
    }
    
    // MARK: - Helper Methods

    /// 按优先级降序排序拦截器（优先级高的先执行）
    private func sortInterceptors(_ interceptors: [iNtkInterceptor]) -> [iNtkInterceptor] {
        interceptors.sorted { $0.priority > $1.priority }
    }

    // MARK: - Core Execution

    func execute() async throws -> NtkResponse<ResponseData> {
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client, cacheableClient: config.cacheableClient)

        // 动态添加核心拦截器
        var executionCoreInterceptors = config.coreInterceptors
        executionCoreInterceptors.append(NtkDeduplicationInterceptor())
        executionCoreInterceptors.append(config.dataParsingInterceptor)

        let allInterceptors = sortInterceptors(config.interceptors + executionCoreInterceptors)
        
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
        }
    }
    
    func loadCache() async throws -> NtkResponse<ResponseData>? {
        guard let cacheableClient = config.cacheableClient else {
            return nil
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client, cacheableClient: cacheableClient)

        var executionCoreInterceptors = config.coreInterceptors
        executionCoreInterceptors.append(config.dataParsingInterceptor)
        let tmpInterceptors = sortInterceptors(executionCoreInterceptors)

        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            if let response = try await cacheableClient.loadCache(context.mutableRequest) {
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
        }
    }
    
    func hasCacheData() async -> Bool where ResponseData == Bool {
        guard let cacheableClient = config.cacheableClient else {
            return false
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client, cacheableClient: cacheableClient)

        // hasCacheData 可能不需要完整的拦截器链，但为了保持一致性，使用已配置的拦截器
        let sortedInterceptors = sortInterceptors(config.interceptors)

        let realChainManager = NtkInterceptorChainManager(interceptors: sortedInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            return await cacheableClient.hasCacheData(context.mutableRequest)
        }
        
        do {
            let response = try await realChainManager.execute(context: context) as? NtkResponse<Bool>
            return response?.data ?? false
        } catch {
            return false
        }
    }
}
