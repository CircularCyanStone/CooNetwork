//
//  iNtkRequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

/// 请求处理器协议
/// 拦截器链中的下一个处理节点，拦截器通过调用 handle 将请求传递给链中的下一环
@NtkActor
public protocol iNtkRequestHandler: Sendable {
    /// 处理请求并返回响应
    /// - Parameter context: 拦截器上下文
    /// - Returns: 响应对象
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse
}
