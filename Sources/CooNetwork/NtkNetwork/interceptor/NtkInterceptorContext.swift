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

    let requestIdentity: NtkRequestIdentity?
    let deduplicationIdentity: NtkDeduplicationIdentity?
    let effectiveTimeout: TimeInterval

    init(
        request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity? = nil,
        deduplicationIdentity: NtkDeduplicationIdentity? = nil,
        effectiveTimeout: TimeInterval = NtkEffectiveTimeoutResolver.builtInDefault,
        extraData: [String: any Sendable] = [:]
    ) {
        self.request = request
        self.requestIdentity = requestIdentity
        self.deduplicationIdentity = deduplicationIdentity
        self.effectiveTimeout = effectiveTimeout
        self.extraData = extraData
    }
}
