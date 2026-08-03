//
//  NtkConfiguration.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2026/1/6.
//
/**
 CooNetwork 全局配置

 配置应在应用启动时通过 configure() 设置
 */
import Foundation

/// CooNetwork 全局配置
/// 配置应在应用启动时通过 configure() 设置
public struct NtkConfiguration: Sendable {

    /// 配置构建器
    public struct Builder : Sendable{
        /// 日志开关（默认关闭）
        public var isLoggingEnabled: Bool = false

        /// 是否全局启用去重功能（默认启用）
        public var isDeduplicationEnabled: Bool = true

        /// 默认请求超时时间（秒）
        /// - Note: 所有请求的超时配置都以此值为基准
        public var defaultTimeout: TimeInterval = 20

        /// executor 创建时冻结的全局请求 key 策略。
        ///
        /// 默认 `.strict` 不排除任何字段，优先防止跨 user/tenant 的错误缓存或去重合并。
        /// 应用应在启动配置阶段集中声明确认不区分资源的公共动态字段；请求级非 `nil` 策略会
        /// 完整替换此值而不是合并。排除鉴权字段时必须用稳定字段或 `setRequestIdentityValue`
        /// 保留主体隔离；字段转换闭包失败时仅关闭本次缓存和去重，网络请求继续。
        public var requestIdentityPolicy: NtkRequestIdentityPolicy = .strict
    }

    /// 内部存储 — nonisolated(unsafe) 是必需的，因为 static 存储属性需要在全局隔离域外访问。
    /// 所有对 _current 的读写必须通过 withLock 进行，禁止直接访问。
    nonisolated(unsafe) private static var _current = NtkConfiguration()

    private static let lock = NtkUnfairLock()

    /// 在锁保护下访问 _current 的唯一入口
    private static func withLock<R>(_ body: (inout NtkConfiguration) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_current)
    }

    /// 当前配置的不可变快照（线程安全）
    /// 每次读取返回一份值拷贝，不会读到半更新状态
    public static var current: NtkConfiguration {
        withLock { $0 }
    }

    /// 配置快照，创建后不可变
    internal let builder: Builder

    init(builder: Builder = Builder()) {
        self.builder = builder
    }

    /// 更新全局配置（生成新快照，原子替换）
    /// - Parameter configuration: 配置修改闭包
    public static func configure(_ configuration: (inout Builder) -> Void) {
        withLock { config in
            var newBuilder = config.builder
            configuration(&newBuilder)
            config = NtkConfiguration(builder: newBuilder)
        }
    }
}
