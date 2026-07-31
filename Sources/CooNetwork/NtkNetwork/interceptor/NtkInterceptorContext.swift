//
//  NtkInterceptorContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 拦截器上下文
/// 在拦截器链中传递，携带请求、客户端以及拦截器间共享的额外数据
@NtkActor
public final class NtkInterceptorContext: Sendable {

    /// 当前拦截链使用的只读请求快照。
    ///
    /// 请求结构只能由 `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 构建；
    /// `intercept(context:next:)` 阶段只能读取该值。
    public let request: NtkMutableRequest

    /// 网络客户端
    public let client: iNtkClient

    /// 当前拦截器链一次执行期间共享的运行时状态。
    ///
    /// 普通拦截器可以在 `intercept(context:next:)` 阶段读写该数据，用于在链内传递
    /// 追踪信息、执行状态或响应解析所需的临时信息。响应解析阶段会按需取得其快照。
    ///
    /// 该数据不属于请求结构，不能用于回写或修改已经冻结的 `request`，也不会与
    /// `NtkMutableRequest.extraData` 自动同步。
    public var extraData: [String: Sendable] = [:]

    init(request: NtkMutableRequest, client: iNtkClient) {
        self.request = request
        self.client = client
    }
}
