//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络组件错误类型
/// 定义了网络请求过程中对外暴露的公共失败事件
public enum NtkError: Error, Sendable {
    case invalidRequest
    case unsupportedRequestType
    case invalidResponseType
    case invalidTypedResponse
    case responseBodyEmpty
    case requestCancelled
    case requestTimeout

    /// 缓存相关错误
    public enum Cache: Error, Sendable {
        /// 没有缓存数据
        case noCache
    }
}
