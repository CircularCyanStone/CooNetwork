//
//  NtkNetworkExecutor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/11.
//

import Foundation

/// 网络请求执行器
/// 负责实际执行网络请求、缓存加载和拦截器链的处理
/// 这是一个不可变的执行快照，可安全地跨并发任务共享。
final class NtkNetworkExecutor<ResponseData: Sendable>: Sendable {

    /// 响应结果枚举，用于区分缓存和网络响应
    enum ResponseResult: Sendable {
        case cache(NtkResponse<ResponseData>?)
        case network(NtkResponse<ResponseData>)
    }

    /// 执行器配置快照
    /// 由 NtkNetwork 在 getOrCreateExecutor() 时冻结，执行期间不可变
    struct Configuration: Sendable {
        let client: any iNtkClient
        let request: NtkMutableRequest
        let interceptors: [any iNtkInterceptor]
        let requestIdentityPolicy: NtkRequestIdentityPolicy
        let isDeduplicationEnabled: Bool
        let defaultTimeout: TimeInterval
        let deduplicationNamespace: String

        init(
            client: any iNtkClient,
            request: NtkMutableRequest,
            interceptors: [any iNtkInterceptor],
            globalConfiguration: NtkConfiguration = .current,
            deduplicationNamespace: String = "default"
        ) {
            var request = request
            request.refreshConfigurationSnapshot()
            let builder = globalConfiguration.builder
            self.client = client
            self.request = request
            self.interceptors = interceptors
            self.requestIdentityPolicy = request.requestIdentityPolicy ?? builder.requestIdentityPolicy
            self.isDeduplicationEnabled = builder.isDeduplicationEnabled
            self.defaultTimeout = builder.defaultTimeout
            self.deduplicationNamespace = deduplicationNamespace
        }
    }

    private let config: Configuration
    /// 执行器创建时冻结的初始请求快照。
    /// 每条执行路径从该快照创建自己的上下文，不在路径之间回写共享请求。
    private let initialRequest: NtkMutableRequest
    private let cacheProvider: (any iNtkCacheProvider)?

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

    /// 在请求修改完成后冻结本次路径共用的身份和有效超时。
    private func makeContext(
        includeDeduplication: Bool,
        includeCache: Bool
    ) async throws -> NtkInterceptorContext {
        var request = try await makeRequest()
        request.pruneIdentityMetadata()
        let effectiveTimeout = NtkEffectiveTimeoutResolver.resolve(
            requested: request.timeout,
            configuredDefault: config.defaultTimeout
        )
        request.applyEffectiveTimeout(effectiveTimeout)

        let deduplicationEnabled = includeDeduplication &&
            config.isDeduplicationEnabled && request.isDeduplicationEnabled
        let cacheEnabled = includeCache && request.cacheConfiguration?.isEnabled == true
        let identity: NtkRequestIdentity?
        if deduplicationEnabled || cacheEnabled {
            do {
                identity = try NtkRequestIdentityBuilder.build(
                    request: request,
                    policy: config.requestIdentityPolicy
                )
            } catch let failure as NtkRequestIdentityBuilder.Failure {
                logger.warning(
                    "Request identity unavailable: \(failure.diagnosticDescription)",
                    category: .identity
                )
                identity = nil
            }
        } else {
            identity = nil
        }

        let deduplicationIdentity = deduplicationEnabled ? identity.map {
            NtkDeduplicationIdentity(
                requestIdentity: $0,
                responseType: ObjectIdentifier(ResponseData.self),
                effectiveTimeout: effectiveTimeout,
                namespace: config.deduplicationNamespace
            )
        } : nil

        return NtkInterceptorContext(
            request: request,
            requestIdentity: identity,
            deduplicationIdentity: deduplicationIdentity,
            effectiveTimeout: effectiveTimeout
        )
    }

    // MARK: - Core Execution

    func execute() async throws -> NtkResponse<ResponseData> {
        let context = try await makeContext(
            includeDeduplication: true,
            includeCache: cacheProvider != nil
        )

        // 动态添加核心拦截器（Tier 保证正确排序）
        var interceptorsToRun = config.interceptors
        interceptorsToRun.append(NtkDeduplicationInterceptor())
        let allInterceptors = NtkInterceptorOrdering.sorted(interceptorsToRun)
        
        let realChainManager = NtkInterceptorChainManager(interceptors: allInterceptors) { [client = config.client] context in
            let response = try await client.execute(context.request)
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
        let context = try await makeContext(
            includeDeduplication: false,
            includeCache: true
        )

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
        guard let context = try? await makeContext(
            includeDeduplication: false,
            includeCache: true
        ) else { return false }
        return await cacheProvider.hasCacheData(for: context.request)
    }
}
