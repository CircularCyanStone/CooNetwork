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

    /// 执行器配置快照。
    ///
    /// 这是 request identity 进入执行框架的第一个位置：`NtkNetwork.getOrCreateExecutor()` 首次创建
    /// executor 时，把原始请求、全局 request identity policy、去重开关、默认超时和 namespace 一次性
    /// 冻结。之后即使应用再次修改 `NtkConfiguration` 或 network builder，已有 executor 也不会
    /// 混用新旧配置。
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
            // 请求协议的默认 timeout 可能读取全局配置；在冻结点重新取一次并存进值类型快照，
            // 防止后续每条执行路径从 originalRequest 读取到不同时间点的配置。
            request.refreshConfigurationSnapshot()
            let builder = globalConfiguration.builder
            self.client = client
            self.request = request
            self.interceptors = interceptors
            // 请求级 policy 是完整替换，不是与全局排除集合合并。这样特殊接口可以明确重新纳入
            // 被全局排除的字段，不会出现无法撤销的隐式规则。
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
    
    /// 从初始请求快照按请求修改器优先级构建本次动作的最终请求。
    ///
    /// 每次 `execute`、`loadCache`、`hasCacheData` 都从同一初始值复制后重新运行修改器，路径之间
    /// 不回写。request identity 因此包含修改器真正注入的 token、公共参数和附加 key/value；同时也意味着
    /// `requestWithCache()` 的缓存读取与网络执行会各运行一次修改器，动态字段必须通过
    /// `.exclude`/policy 正确排除，才能让两条路径得到同一个资源 key。
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

    /// 在请求修改完成后生成本次路径共用的 request identity、deduplication key 和有效超时。
    ///
    /// 这是 requestIdentity 目录在执行框架中的实际调用入口。方法先得到修改器生成的最终请求，再解析
    /// timeout。`NtkMutableRequest` 的写入方法已经同步维护真实字段与字段级 key 规则，因此请求
    /// 到达这里时不需要再执行一次补救性清理。只有缓存或去重至少有一个消费者真正启用时才构建
    /// 资源 key，避免无消费者时执行转换闭包或为不支持参数产生无意义警告。
    ///
    /// 构建成功后，request identity 和有效 timeout 被放进不可变 context；普通 interceptor 无法
    /// 替换它们。构建失败只令 request identity 为 nil：缓存会跳过，去重会退化为 instance UUID 隔离，
    /// 网络和框架 timeout 仍继续。请求修改器本身抛错发生在 key 构建前，仍由本方法向上抛出。
    private func makeContext(
        includeDeduplication: Bool,
        includeCache: Bool
    ) async throws -> NtkInterceptorContext {
        var request = try await makeRequest()

        /// 合并多维度的超时时间，统一去重时超时时间的稳定性。
        let effectiveTimeout = NtkRequestTimeoutResolver.resolve(
            requested: request.timeout,
            configuredDefault: config.defaultTimeout
        )
        request.applyEffectiveTimeout(effectiveTimeout)

        let requestDeduplicationEnabled: Bool
        switch request.deduplicationPolicy {
        case .inherit:
            requestDeduplicationEnabled = config.isDeduplicationEnabled
        case .enabled:
            requestDeduplicationEnabled = true
        case .disabled:
            requestDeduplicationEnabled = false
        }
        let deduplicationEnabled = includeDeduplication && requestDeduplicationEnabled
        let cacheEnabled = includeCache && request.cacheConfiguration?.isEnabled == true
        let logPath = URLComponents(string: request.path)?.path ?? "<redacted>"
        logger.debug(
            "请求执行准备完成：method=\(request.method.rawValue) path=\(logPath) requestID=\(request.instanceIdentifier.uuidString)；有效超时=\(effectiveTimeout)s，缓存=\(cacheEnabled)，去重=\(deduplicationEnabled)。",
            category: .network
        )

        let requestIdentity: NtkRequestIdentity?
        if deduplicationEnabled || cacheEnabled {
            do {
                // 单条网络执行路径只构建这一份 request identity。下面生成的 deduplication key 和响应阶段的
                // NtkCacheInterceptor 都引用它，禁止各自根据 request 重算 key。
                let builtRequestIdentity = try NtkRequestIdentityBuilder.build(
                    request: request,
                    policy: config.requestIdentityPolicy
                )
                requestIdentity = builtRequestIdentity
                logger.debug(
                    "请求身份生成成功：requestID=\(request.instanceIdentifier.uuidString) identity=\(builtRequestIdentity.value)；影响=缓存和去重将使用此身份关联同一资源。",
                    category: .requestIdentity
                )
            } catch let error as NtkRequestIdentityBuilder.BuildError {
                // 失败内容已经由 BuildError 脱敏。这里不抛 NtkError，因为缓存和去重是可选优化，
                // 参数仍可能完全能够被具体 HTTP client 正常序列化和发送。
                logger.warning(
                    "请求身份生成失败：requestID=\(request.instanceIdentifier.uuidString)，原因=\(error.logMessage)；影响=本次跳过缓存和去重，网络请求继续执行。",
                    category: .requestIdentity
                )
                requestIdentity = nil
            }
        } else {
            requestIdentity = nil
            logger.debug(
                "请求身份未生成：requestID=\(request.instanceIdentifier.uuidString)，原因=未启用缓存和去重；影响=不影响网络请求。",
                category: .requestIdentity
            )
        }

        // 缓存只关心资源 key；去重共享的是完整执行结果，所以还必须隔离响应泛型、实际
        // timeout 和执行 namespace。四者任一不同都会创建独立底层任务。
        let deduplicationKey = deduplicationEnabled ? requestIdentity.map {
            NtkDeduplicationKey(
                requestIdentity: $0,
                responseType: ObjectIdentifier(ResponseData.self),
                effectiveTimeout: effectiveTimeout,
                namespace: config.deduplicationNamespace
            )
        } : nil

        if let deduplicationKey {
            logger.debug(
                "去重条件已就绪：requestID=\(request.instanceIdentifier.uuidString) identity=\(deduplicationKey.requestIdentity.value) timeout=\(deduplicationKey.effectiveTimeout)s；影响=相同身份且超时一致的请求可复用进行中的任务。",
                category: .deduplication
            )
        } else {
            let reason = deduplicationEnabled ? "请求身份不可用" : "请求去重未启用"
            logger.debug(
                "去重未生效：requestID=\(request.instanceIdentifier.uuidString)，原因=\(reason)；影响=本次请求独立执行。",
                category: .deduplication
            )
        }

        return NtkInterceptorContext(
            request: request,
            requestIdentity: requestIdentity,
            deduplicationKey: deduplicationKey,
            effectiveTimeout: effectiveTimeout
        )
    }

    // MARK: - Core Execution

    func execute() async throws -> NtkResponse<ResponseData> {
        let context: NtkInterceptorContext
        do {
            context = try await makeContext(
                includeDeduplication: true,
                includeCache: cacheProvider != nil
            )
        } catch {
            logger.error(
                "请求执行准备失败：requestID=\(initialRequest.instanceIdentifier.uuidString)，原因=\(String(reflecting: type(of: error)))；影响=请求未发送，调用方将收到失败结果。",
                category: .network
            )
            throw error
        }

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
        } catch {
            if case NtkError.requestCancelled = error {
                logger.debug(
                    "请求执行已取消：requestID=\(context.request.instanceIdentifier.uuidString)；影响=不再等待本次请求结果。",
                    category: .network
                )
            } else {
                logger.error(
                    "请求执行失败：requestID=\(context.request.instanceIdentifier.uuidString)，原因=\(String(reflecting: type(of: error)))；影响=调用方将收到失败结果。",
                    category: .network
                )
            }
            throw error
        }
    }
    
    func loadCache() async throws -> NtkResponse<ResponseData>? {
        guard let cacheProvider else {
            logger.debug(
                "缓存读取已跳过：requestID=\(initialRequest.instanceIdentifier.uuidString)，原因=未配置缓存提供者；影响=本次没有缓存结果。",
                category: .cache
            )
            return nil
        }
        let context = try await makeContext(
            includeDeduplication: false,
            includeCache: true
        )
        guard let requestIdentity = context.requestIdentity else {
            logger.debug(
                "缓存读取已跳过：requestID=\(context.request.instanceIdentifier.uuidString)，原因=请求身份不可用；影响=本次没有缓存结果。",
                category: .cache
            )
            return nil
        }

        let parserInterceptors = NtkInterceptorOrdering.sorted(config.interceptors)
            .filter { $0 is NtkResponseParserBox }

        let realChainManager = NtkInterceptorChainManager(interceptors: parserInterceptors) { context in
            guard let data = try await cacheProvider.loadCacheData(
                for: context.request,
                requestIdentity: requestIdentity
            ) else {
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
        guard let cacheProvider else {
            logger.debug(
                "缓存可用性检查已跳过：requestID=\(initialRequest.instanceIdentifier.uuidString)，原因=未配置缓存提供者；影响=返回无缓存。",
                category: .cache
            )
            return false
        }
        let context: NtkInterceptorContext
        do {
            context = try await makeContext(
                includeDeduplication: false,
                includeCache: true
            )
        } catch {
            logger.warning(
                "缓存可用性检查失败：requestID=\(initialRequest.instanceIdentifier.uuidString)，原因=\(String(reflecting: type(of: error)))；影响=返回无缓存。",
                category: .cache
            )
            return false
        }
        guard let requestIdentity = context.requestIdentity else {
            logger.debug(
                "缓存可用性检查已跳过：requestID=\(context.request.instanceIdentifier.uuidString)，原因=请求身份不可用；影响=返回无缓存。",
                category: .cache
            )
            return false
        }
        return await cacheProvider.hasCacheData(for: context.request, requestIdentity: requestIdentity)
    }
}
