//
//  TFNMutableRequest.swift
//  TFNNetwork
//
//  Created by TFNNetwork on 2024/01/01.
//  Copyright © 2024 TFNNetwork. All rights reserved.
//

import Foundation

/// 可变请求包装器，用于在拦截器中动态修改请求参数和头部信息
/// 完全替代 TFNRequestWrapper，提供更强大的请求修改能力
struct TFNMutableRequest: iTFNRequest {
    
    // MARK: - 原始请求属性（不可变）
    
    /// 原始请求对象
    let originalRequest: iTFNRequest
    
    // MARK: - 可变属性（直接存储，与iTFNRequest使用习惯一致）
    
    /// 请求参数，可直接修改
    var parameters: [String: Sendable]?
    
    /// 请求头，可直接修改
    var headers: [String: String]?
    
    /// 额外数据存储，用于在拦截器间传递自定义信息
    var extra: [String: Sendable] = [:]
    
    // MARK: - 初始化
    
    /// 使用原始请求初始化可变请求包装器
    /// - Parameter request: 原始请求对象
    init(_ request: iTFNRequest) {
        self.originalRequest = request
        // 复制原始请求的参数和头部到可变属性中
        self.parameters = request.parameters
        self.headers = request.headers
    }
    
    // MARK: - iTFNRequest 协议实现
    
    var baseURL: URL {
        return originalRequest.baseURL
    }
    
    var path: String {
        return originalRequest.path
    }
    
    var method: TFNHTTPMethod {
        return originalRequest.method
    }
    
    var body: Data? {
        return originalRequest.body
    }
    
    var cachePolicy: TFNCachePolicy? {
        return originalRequest.cachePolicy
    }
    
    var checkLogin: Bool {
        return originalRequest.checkLogin
    }
    
    func isServiceSuccess(_ response: any iTFNResponse) -> Bool {
        return originalRequest.isServiceSuccess(response)
    }
    
    // MARK: - 便捷方法
    
    /// 添加单个请求参数
    /// - Parameters:
    ///   - key: 参数键
    ///   - value: 参数值
    mutating func addParameter(key: String, value: Sendable) {
        if parameters == nil {
            parameters = [:]
        }
        parameters?[key] = value
    }
    
    /// 批量添加请求参数
    /// - Parameter parameters: 要添加的参数字典
    mutating func addParameters(_ newParameters: [String: Sendable]) {
        if parameters == nil {
            parameters = [:]
        }
        parameters?.merge(newParameters) { _, new in new }
    }
    
    /// 添加单个请求头
    /// - Parameters:
    ///   - key: 头部键
    ///   - value: 头部值
    mutating func addHeader(key: String, value: String) {
        if headers == nil {
            headers = [:]
        }
        headers?[key] = value
    }
    
    /// 批量添加请求头
    /// - Parameter headers: 要添加的头部字典
    mutating func addHeaders(_ newHeaders: [String: String]) {
        if headers == nil {
            headers = [:]
        }
        headers?.merge(newHeaders) { _, new in new }
    }
    
    /// 移除指定的请求参数
    /// - Parameter key: 要移除的参数键
    mutating func removeParameter(key: String) {
        parameters?.removeValue(forKey: key)
    }
    
    /// 移除指定的请求头
    /// - Parameter key: 要移除的头部键
    mutating func removeHeader(key: String) {
        headers?.removeValue(forKey: key)
    }
    
    /// 清空所有参数
    mutating func clearParameters() {
        parameters = nil
    }
    
    /// 清空所有头部
    mutating func clearHeaders() {
        headers = nil
    }
}

// MARK: - 下标访问支持（兼容原 TFNRequestWrapper）

extension TFNMutableRequest {
    
    /// 通过下标访问 extra 字典
    /// - Parameter key: 键名
    /// - Returns: 对应的值
    public subscript(key: String) -> Sendable? {
        get {
            return extra[key]
        }
        set {
            extra[key] = newValue
        }
    }
}

// MARK: - 调试支持

extension TFNMutableRequest: CustomStringConvertible {
    
    public var description: String {
        return """
        TFNMutableRequest {
            baseURL: \(baseURL)
            path: \(path)
            method: \(method)
            parameters: \(parameters ?? [:])
            headers: \(headers ?? [:])

            extra: \(extra)
        }
        """
    }
}
