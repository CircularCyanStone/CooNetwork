//
//  NtkInterceptorContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 拦截器上下文
/// 在拦截器链中传递，携带请求以及当前请求路径的额外数据。
public struct NtkInterceptorContext: Sendable {

    /// 当前拦截链使用的只读请求快照。
    ///
    /// 请求结构只能由 `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 构建；
    /// `intercept(context:next:)` 阶段只能读取该值。
    public let request: NtkMutableRequest

    /// 当前请求路径的运行时状态。
    ///
    /// 拦截器需要先复制 context，再修改该数据并把副本传给下游，用于传递追踪信息、
    /// 执行状态或响应解析所需的临时信息。修改不会回写上游持有的 context，响应解析阶段
    /// 会按需取得当前副本的快照。
    ///
    /// 该数据不属于请求结构，不能用于回写或修改已经冻结的 `request`，也不会与
    /// `NtkMutableRequest.extraData` 自动同步。
    public var extraData: [String: any Sendable]

    /// 请求修改完成后生成、供缓存与去重共同使用的资源 key。
    ///
    /// `NtkCacheInterceptor` 和显式缓存读取直接消费它；nil 表示未启用相关能力或构建失败，
    /// 下游必须跳过缓存而不是重新从 request 推导另一套 key。保持 internal 可见性也防止普通
    /// 业务 interceptor 替换已经冻结的请求 key。
    let requestIdentity: NtkRequestIdentity?

    /// 供最外层 `NtkDeduplicationInterceptor` 使用的完整去重 key。
    ///
    /// 它在请求 key 上加入响应类型、有效 timeout 和 namespace。nil 时任务管理器仍负责执行和
    /// 超时，但按 request.instanceIdentifier 隔离，不与任何其他请求共享结果。
    let deduplicationKey: NtkDeduplicationKey?

    /// 已完成合法性回退和上限截断的实际超时。
    ///
    /// 该值既已写回只读 request 快照，也会传给任务管理器创建超时竞争任务；禁止下游重新读取
    /// 全局配置，否则用于去重比较的 timeout 可能与真正执行的 timeout 不一致。
    let effectiveTimeout: TimeInterval

    init(
        request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity? = nil,
        deduplicationKey: NtkDeduplicationKey? = nil,
        effectiveTimeout: TimeInterval = NtkRequestTimeoutResolver.builtInDefault,
        extraData: [String: any Sendable] = [:]
    ) {
        self.request = request
        self.requestIdentity = requestIdentity
        self.deduplicationKey = deduplicationKey
        self.effectiveTimeout = effectiveTimeout
        self.extraData = extraData
    }
}
