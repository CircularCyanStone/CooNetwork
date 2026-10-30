//
//  NtkNetworkCache.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation


/// 网络缓存管理器，负责把已经确定的请求 key 映射到缓存存储。
///
/// 缓存不再从 request 计算 key：同一执行路径必须消费 executor 传入、同时供去重使用的 request identity，
/// 从而避免两套算法因字段过滤或版本升级而产生不一致。requestIdentity.value 是不透明的版本化键，不是
/// 鉴权凭证；调用方不得解析它或据此削弱 user、tenant 等业务隔离。
public final class NtkNetworkCache: Sendable {
    /// 缓存存储实现。
    public let storage: iNtkCacheStorage

    /// 使用指定存储创建缓存管理器。
    ///
    /// 管理器不持有请求或自行派生 key，读取和写入必须显式提供同一条执行路径已确定的 request identity。
    /// - Parameter storage: 负责持久化缓存元数据的实现。
    public init(storage: iNtkCacheStorage) {
        self.storage = storage
    }

    /// 使用框架已生成的稳定请求 key 查询缓存是否存在。
    ///
    /// 本方法直接把 requestIdentity.value 传给 storage，绝不从 request 重算第二个 key。executor 仅在有效
    /// 缓存配置且 key 可用时调用它；无效配置或 key 构建失败应在上游返回 false，不影响网络响应。
    /// - Parameters:
    ///   - request: 已完成修改的请求快照，仅供 storage 保留请求关联信息。
    ///   - requestIdentity: 与本次去重共享的稳定、不透明请求 key。
    /// - Returns: storage 报告的缓存存在状态。
    public func hasData(
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async -> Bool {
        await storage.hasData(key: requestIdentity.value, for: request)
    }

    /// 使用框架已生成的稳定请求 key 读取尚未过期的数据。
    ///
    /// requestIdentity 必须与请求修改后构建、供去重使用的 key 完全一致；管理器不重新计算。到期时间等于
    /// 当前时间仍视为有效，早于当前时间才返回 nil。存储错误由调用方决定如何处理，key 构建失败不会到达
    /// 本方法，因此不会阻断网络请求。
    /// - Parameters:
    ///   - request: 已完成修改的请求快照。
    ///   - requestIdentity: 稳定且不透明的缓存 key。
    /// - Returns: 未过期的缓存数据；不存在或已过期时返回 nil。
    /// - Throws: storage 读取失败时抛出的错误。
    public func loadData(
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async throws -> (any Sendable)? {
        guard let cacheMetaData = await storage.getData(key: requestIdentity.value, for: request) else {
            return nil
        }

        guard cacheMetaData.expirationDate >= Date().timeIntervalSince1970 else {
            return nil
        }
        return cacheMetaData.data
    }

    /// 使用框架已生成的稳定请求 key 保存响应数据。
    ///
    /// 只有有限正数的 cacheConfiguration 才允许写入；无效配置返回 false，且该降级绝不影响已获得的
    /// 网络响应。requestIdentity.value 原样交给 storage，不存在第二套 key 算法；调用方必须用稳定字段或
    /// request identity value 维持 user、tenant 隔离，避免排除凭证后跨主体共享。
    ///
    /// 写入前会用 `NtkCacheMeta.canEncode(_:)` 检查数据类型，与解档白名单同源：不属于白名单的响应
    /// （如含 `URL`、`Date`、自定义 Sendable 结构体）直接返回 false 而不落到 storage。这类数据能编码
    /// 却无法完整解回，若放任写入会留下「写成功、读不出」的脏缓存，甚至在 `.raiseException` 策略的
    /// 存储实现里触发 OC 异常。
    /// - Parameters:
    ///   - data: 要保存的响应数据。
    ///   - request: 已完成修改的请求快照，提供缓存配置。
    ///   - requestIdentity: 与本次去重共享的稳定、不透明请求 key。
    /// - Returns: 配置无效或数据类型不可往返时为 false，否则为 storage 的写入结果。
    public func save(
        data: Sendable,
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async -> Bool {
        guard let cacheConfiguration = request.cacheConfiguration,
              cacheConfiguration.isEnabled else {
            return false
        }
        guard NtkCacheMeta.canEncode(data) else {
            return false
        }
        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let createTime = Date().timeIntervalSince1970
        let expirationDate = createTime + cacheConfiguration.cacheTime
        let metaData = NtkCacheMeta(appVersion: versionName, creationDate: createTime, expirationDate: expirationDate, data: data)

        return await storage.setData(metaData: metaData, key: requestIdentity.value, for: request)
    }
}
