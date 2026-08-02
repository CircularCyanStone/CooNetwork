//
//  NtkCacheConfiguration.swift
//  CooNetwork
//

import Foundation

/// 只描述响应缓存有效期与写入资格的请求级配置。
///
/// 该类型不参与请求身份生成；`cacheTime` 与 `shouldCache` 均不会改变资源 key。
/// token、timestamp 等动态字段应通过 `NtkRequestIdentityPolicy` 或字段参与标记处理。
/// 非有限值或小于等于零的有效期会关闭缓存读写，但网络请求仍继续执行。
public struct NtkCacheConfiguration: Sendable {
    /// 缓存有效期（秒）；只有有限且大于零时才启用缓存，不改变资源 key。
    public let cacheTime: TimeInterval

    /// 响应写入资格判断；默认允许写入，返回 `false` 只跳过缓存写入而不影响网络结果或资源 key。
    public let shouldCache: @Sendable (any iNtkResponse) -> Bool

    /// 创建独立的响应缓存配置。
    ///
    /// 默认允许所有响应写入。无效时长会关闭缓存但网络继续；字段过滤必须改用身份策略或字段
    /// 标记，不能通过此配置改变资源 key。
    /// - Parameters:
    ///   - cacheTime: 缓存有效期（秒）；必须有限且大于零才启用。
    ///   - shouldCache: 响应写入资格判断，默认返回 `true`。
    public init(
        cacheTime: TimeInterval,
        shouldCache: @escaping @Sendable (any iNtkResponse) -> Bool = { _ in true }
    ) {
        self.cacheTime = cacheTime
        self.shouldCache = shouldCache
    }

    /// 返回 30 天有效期且默认允许响应写入的配置。
    ///
    /// 该默认值只控制缓存生命周期，不过滤身份字段，也不改变资源 key。
    public static func `default`() -> Self {
        Self(cacheTime: 30 * 24 * 60 * 60)
    }

    /// 创建指定有效期且默认允许响应写入的配置。
    ///
    /// 非有限值或小于等于零时缓存关闭、网络继续；该方法不改变身份投影或资源 key。
    /// - Parameter duration: 缓存有效期（秒）。
    /// - Returns: 使用指定有效期的缓存配置。
    public static func custom(duration: TimeInterval) -> Self {
        Self(cacheTime: duration)
    }

    /// 当前有效期是否允许缓存读写；无效值只触发缓存降级，不影响网络执行。
    internal var isEnabled: Bool {
        cacheTime.isFinite && cacheTime > 0
    }
}
