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
        let client: iNtkClient
        let request: NtkMutableRequest
        let interceptors: [iNtkInterceptor]
    }

    private let config: Configuration
    /// 执行器创建时冻结的初始请求快照。
    /// 每条执行路径从该快照创建自己的上下文，不在路径之间回写共享请求。
    private let initialRequest: NtkMutableRequest
    private let cacheProvider: (any iNtkCacheProvider)?

    nonisolated
    init(config: Configuration) {
        self.config = config
        self.initialRequest = config.request
        self.cacheProvider = config.interceptors.first(where: { $0 is iNtkCacheProvider }) as? iNtkCacheProvider
    }
    
    /// 从初始请求快照按请求修改器的优先级顺序构建本次动作的请求。
    private func makeRequest() async throws -> NtkMutableRequest {
        var request = initialRequest
        let requestModifiers = NtkInterceptorOrdering.sorted(config.interceptors).compactMap {
            $0 as? any iNtkRequestModifyingInterceptor
        }
        for interceptor in requestModifiers {
            request = try await interceptor.modifyRequest(request)
        }
        return request
    }

    // MARK: - Core Execution

    func execute() async throws -> NtkResponse<ResponseData> {
        let request = try await makeRequest()
        let context = NtkInterceptorContext(request: request, client: config.client)

        // 动态添加核心拦截器（Tier 保证正确排序）
        var interceptorsToRun = config.interceptors
        interceptorsToRun.append(NtkDeduplicationInterceptor())
        let allInterceptors = NtkInterceptorOrdering.sorted(interceptorsToRun)
        
        let realChainManager = NtkInterceptorChainManager(interceptors: allInterceptors) { context in
            let response = try await context.client.execute(context.request)
            return response
        }
        
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            } else {
                throw NtkError.invalidTypedResponse
            }
        }
    }
    
    func loadCache() async throws -> NtkResponse<ResponseData>? {
        guard let cacheProvider else {
            return nil
        }
        let request = try await makeRequest()
        let context = NtkInterceptorContext(request: request, client: config.client)

        let parserInterceptors = NtkInterceptorOrdering.sorted(config.interceptors)
            .filter { $0 is NtkResponseParserBox }

        let realChainManager = NtkInterceptorChainManager(interceptors: parserInterceptors) { context in
            guard let data = try await cacheProvider.loadCacheData(for: context.request) else {
                throw NtkError.Cache.noCache
            }
            return NtkClientResponse(data: data, msg: nil, response: data, request: context.request, isCache: true)
        }

        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            } else {
                throw NtkError.invalidTypedResponse
            }
        } catch NtkError.Cache.noCache {
            return nil
        }
    }

    func hasCacheData() async -> Bool where ResponseData == Bool {
        guard let cacheProvider else { return false }
        guard let request = try? await makeRequest() else { return false }
        return await cacheProvider.hasCacheData(for: request)
    }
}
