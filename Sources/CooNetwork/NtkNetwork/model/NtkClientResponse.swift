//
//  NtkClientResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/29.
//

import Foundation

/// 客户端原始响应
/// 用于拦截器链中传递的中间响应对象，在数据解析前使用
public struct NtkClientResponse: iNtkResponse {

    public typealias ResponseData = Sendable

    /// 响应状态码，默认为 -1 表示未设置
    public private(set) var code: NtkReturnCode = NtkReturnCode(-1)

    /// 响应数据
    public let data: any ResponseData

    /// 响应消息
    public let msg: String?

    /// 原始响应对象
    public let response: any Sendable

    /// 关联的请求对象
    public let request: any iNtkRequest

    /// 是否来自缓存
    public let isCache: Bool

    /// 初始化客户端响应
    /// - Parameters:
    ///   - data: 响应数据
    ///   - msg: 响应消息
    ///   - response: 原始响应对象
    ///   - request: 关联的请求
    ///   - isCache: 是否来自缓存
    public init(data: any ResponseData, msg: String?, response: any Sendable, request: any iNtkRequest, isCache: Bool) {
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
        self.isCache = isCache
    }

    /// 更新响应状态码
    /// - Parameter code: 新的状态码
    public mutating func updateCode(_ code: NtkReturnCode) {
        self.code = code
    }
}
