//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络组件错误类型
/// 定义了网络请求过程中可能出现的各种错误情况
public enum NtkError: Error, Sendable {
    case request(RequestFailure)
    case response(ResponseFailure)
    case serialization(SerializationFailure)
    case validation(ValidationFailure)
    case client(ClientFailure)

    /// 缓存相关错误
    enum Cache: Error {
        /// 没有缓存数据
        case noCache
    }
}
