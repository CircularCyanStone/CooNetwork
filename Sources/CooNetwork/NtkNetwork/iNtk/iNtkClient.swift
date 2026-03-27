//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络客户端协议
/// 定义了网络请求执行的核心接口，支持不同的网络实现（如RPC、HTTP等）
public protocol iNtkClient: Sendable {

    /// 执行网络请求
    /// - Returns: 原始的网络响应数据
    /// - Throws: 网络请求过程中的错误
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse

    /// 取消当前请求
    func cancel()
}

public extension iNtkClient {
    /// 默认的取消实现
    /// 大多数客户端不支持直接取消，应使用Task.cancel()
    func cancel() {
        fatalError("\(self) not support, please use task.cancel()")
    }
}
