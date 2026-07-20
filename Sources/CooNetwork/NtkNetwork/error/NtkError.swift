//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 超时来源描述
/// 轻量级设计，主要用于日志输出和问题排查
public struct NtkTimeoutReason: Sendable, CustomStringConvertible {
    public let source: String
    public let detail: String?

    public init(source: String, detail: String? = nil) {
        self.source = source
        self.detail = detail
    }

    public var description: String {
        if let detail = detail {
            return "\(source): \(detail)"
        }
        return source
    }
}

// 提供便捷构造器
public extension NtkTimeoutReason {
    /// 框架内部 Task 超时
    static func framework(timeout: TimeInterval) -> Self {
        .init(source: "Framework", detail: "\(timeout)s")
    }

    /// URLSession 超时
    static func urlSession(timeout: TimeInterval) -> Self {
        .init(source: "URLSession", detail: "\(timeout)s")
    }

    /// 自定义客户端超时（业务层自由定义）
    static func client(_ name: String, detail: String? = nil) -> Self {
        .init(source: name, detail: detail)
    }
}

/// 网络组件错误类型
/// 定义了网络请求过程中对外暴露的公共失败事件
public enum NtkError: Error, Sendable {
    case invalidRequest
    case unsupportedRequestType(request: any iNtkRequest)
    case invalidResponseType(response: any iNtkResponse)
    case invalidTypedResponse
    case responseBodyEmpty(clientResponse: NtkClientResponse)
    case requestCancelled
    case requestTimeout(NtkTimeoutReason)

    /// 缓存相关错误
    public enum Cache: Error, Sendable {
        /// 没有缓存数据
        case noCache
    }
}
