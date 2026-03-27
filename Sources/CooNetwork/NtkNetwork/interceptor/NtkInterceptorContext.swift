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

    /// 可修改的请求对象
    public var mutableRequest: NtkMutableRequest

    /// 网络客户端
    public let client: iNtkClient

    /// 拦截器间传递的额外数据
    public var extraData: [String: Sendable] = [:]

    init(mutableRequest: NtkMutableRequest, client: iNtkClient) {
        self.mutableRequest = mutableRequest
        self.client = client
    }
}
