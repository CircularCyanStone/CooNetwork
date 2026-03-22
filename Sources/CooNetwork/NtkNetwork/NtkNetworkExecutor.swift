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
        let request: NtkMutableRequest
        let interceptors: [iNtkInterceptor]
        var coreInterceptors: [iNtkInterceptor]
        let validation: iNtkResponseValidation
        let dataParsingInterceptor: iNtkInterceptor
    }

    private let config: Configuration
    private var mutableRequest: NtkMutableRequest
    private let cacheProvider: (any iNtkCacheProvider)?

    nonisolated
    init(config: Configuration) {
        self.config = config
        self.mutableRequest = config.request
        self.cacheProvider = config.interceptors.first(where: { $0 is iNtkCacheProvider }) as? iNtkCacheProvider
    }
    
    // MARK: - Helper Methods

    /// 按优先级降序排序拦截器（优先级高的先执行）
    private func sortInterceptors(_ interceptors: [iNtkInterceptor]) -> [iNtkInterceptor] {
        interceptors.sorted { $0.priority > $1.priority }
    }

    // MARK: - Core Execution

    func execute() async throws -> NtkResponse<ResponseData> {
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

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
        guard let cacheProvider else {
            return nil
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

        var executionCoreInterceptors = config.coreInterceptors
        executionCoreInterceptors.append(config.dataParsingInterceptor)
        let tmpInterceptors = sortInterceptors(executionCoreInterceptors)

        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            guard let data = try await cacheProvider.loadCacheData(for: context.mutableRequest) else {
                throw NtkError.Cache.noCache
            }
            return NtkClientResponse(data: data, msg: nil, response: data, request: context.mutableRequest, isCache: true)
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
        guard let cacheProvider else {
            return false
        }
        let context = NtkInterceptorContext(mutableRequest: mutableRequest, validation: config.validation, client: config.client)

        let sortedInterceptors = sortInterceptors(config.interceptors)

        let realChainManager = NtkInterceptorChainManager(interceptors: sortedInterceptors) { [weak self] context in
            self?.mutableRequest = context.mutableRequest
            let result = await cacheProvider.hasCacheData(for: context.mutableRequest)
            let response = NtkResponse(code: .init(200), data: result, msg: nil, response: result, request: context.mutableRequest, isCache: true)
            return response
        }

        do {
            let response = try await realChainManager.execute(context: context) as? NtkResponse<Bool>
            return response?.data ?? false
        } catch {
            return false
        }
    }
}
