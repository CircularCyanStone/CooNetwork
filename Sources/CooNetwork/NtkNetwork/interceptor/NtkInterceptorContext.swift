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

    /// 当前拦截链使用的请求快照。
    ///
    /// 请求结构只能在 `iNtkRequestModifyingInterceptor.modifyRequest` 阶段修改；拦截器链只能读取该快照，
    /// 从而避免响应处理和请求状态修改混在同一个接口中。
    public let request: NtkMutableRequest

    /// 网络客户端
    public let client: iNtkClient

    /// 拦截器间传递的额外数据
    public var extraData: [String: Sendable] = [:]

    init(request: NtkMutableRequest, client: iNtkClient) {
        self.request = request
        self.client = client
    }
}
