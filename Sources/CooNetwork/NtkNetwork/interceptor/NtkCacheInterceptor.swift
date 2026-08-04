//
//  NtkCacheInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/15.
//

/// 默认缓存拦截器
/// 负责处理网络请求的缓存逻辑，在响应验证通过后执行缓存操作
import Foundation

/// 响应提取器闭包类型，用于从不同类型的响应中提取数据
public typealias ResponseExtractor = @Sendable (any iNtkResponse) -> Sendable?

/// 默认缓存拦截器实现。
///
/// 拦截器只消费 executor 在请求修改后确定的 request identity，绝不根据 request 自行推导 key，因此缓存
/// 与去重共享同一个 key。缓存配置无效、key 构建失败、响应不符合写入资格或数据无法提取时都会跳过写入，
/// 已成功的网络响应照常返回；排除凭证时调用方仍须保留 user、tenant 等稳定隔离字段。
public struct NtkCacheInterceptor: iNtkInterceptor, iNtkCacheProvider {
    /// 拦截器优先级
    /// 使用最低优先级（0），确保在所有其他拦截器之后执行
    public let priority: NtkInterceptorPriority = .innerLow

    /// 缓存存储器
    private let storage: iNtkCacheStorage

    /// 响应提取器，用于从响应中提取需要缓存的数据
    private let responseExtractor: ResponseExtractor

    /// 使用默认响应提取器创建缓存拦截器。
    ///
    /// 默认提取 `response.response`。storage key 始终来自 context 中不透明的 request identity，不能由存储
    /// 或拦截器重新计算；缓存失败不会改变网络响应。
    public init(storage: iNtkCacheStorage) {
        self.storage = storage
        self.responseExtractor = Self.defaultResponseExtractor
    }

    /// 使用自定义响应提取器创建缓存拦截器。
    ///
    /// 提取器只决定是否存在可写入的数据，不能改变请求 key 或真实请求；返回 nil 会安全跳过缓存写入。
    /// - Parameters:
    ///   - storage: 缓存存储器
    ///   - responseExtractor: 自定义的响应提取器闭包
    public init(storage: iNtkCacheStorage, responseExtractor: @escaping ResponseExtractor) {
        self.storage = storage
        self.responseExtractor = responseExtractor
    }

    /// 默认提取器保留响应承载的数据，并保持闭包可跨并发边界安全传递。
    private static let defaultResponseExtractor: ResponseExtractor = { response in
        response.response
    }
    /// 先执行内层链并在成功响应后尝试写入缓存。
    ///
    /// 只有有效缓存配置、已确定 request identity、写入资格和可提取数据同时具备才访问 storage。任何一个条件
    /// 缺失都直接返回网络响应，保证 key 构建失败不会转换成 NtkError 或阻塞网络。
    public func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        if context.request.cacheConfiguration?.isEnabled == true, context.requestIdentity == nil {
            logger.debug(
                "缓存写入已跳过：requestID=\(context.request.instanceIdentifier.uuidString)，原因=请求身份不可用；影响=本次网络响应不会写入缓存。",
                category: .cache
            )
        }
        guard let cacheConfiguration = context.request.cacheConfiguration,
              cacheConfiguration.isEnabled,
              let requestIdentity = context.requestIdentity,
              cacheConfiguration.shouldCache(response),
              let extractedResponse = responseExtractor(response) else {
            return response
        }
        let cache = NtkNetworkCache(storage: storage)
        let result = await cache.save(
            data: extractedResponse,
            for: context.request,
            requestIdentity: requestIdentity
        )
        logger.debug(
            "缓存写入\(result ? "成功" : "失败")：requestID=\(context.request.instanceIdentifier.uuidString) identity=\(requestIdentity.value)；影响=\(result ? "后续相同资源可读取缓存。" : "后续请求仍会走网络。")",
            category: .cache
        )
        return response
    }

    // MARK: - iNtkCacheProvider

    public func loadCacheData(
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async throws -> (any Sendable)? {
        let cache = NtkNetworkCache(storage: storage)
        do {
            let data = try await cache.loadData(for: request, requestIdentity: requestIdentity)
            logger.debug(
                "缓存读取\(data == nil ? "未命中" : "命中")：requestID=\(request.instanceIdentifier.uuidString) identity=\(requestIdentity.value)；影响=\(data == nil ? "继续请求网络。" : "返回缓存数据。")",
                category: .cache
            )
            return data
        } catch {
            logger.warning(
                "缓存读取失败：requestID=\(request.instanceIdentifier.uuidString) identity=\(requestIdentity.value)，原因=\(String(reflecting: type(of: error)))；影响=缓存不可用，调用方将继续网络请求。",
                category: .cache
            )
            throw error
        }
    }

    public func hasCacheData(
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async -> Bool {
        let cache = NtkNetworkCache(storage: storage)
        let hasData = await cache.hasData(for: request, requestIdentity: requestIdentity)
        logger.debug(
            "缓存可用性检查\(hasData ? "命中" : "未命中")：requestID=\(request.instanceIdentifier.uuidString) identity=\(requestIdentity.value)；影响=\(hasData ? "存在可用缓存。" : "不存在可用缓存。")",
            category: .cache
        )
        return hasData
    }
}
