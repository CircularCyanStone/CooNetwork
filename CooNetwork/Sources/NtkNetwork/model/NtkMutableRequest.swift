//
//  NtkMutableRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

/// 可变请求包装器，用于在拦截器中动态修改请求参数和头部信息
/// 完全替代原有设计，提供更强大的请求修改能力
public struct NtkMutableRequest: iNtkRequest {

    // MARK: - 原始请求属性（不可变）

    /// 原始请求对象
    public let originalRequest: iNtkRequest

    // MARK: - 可变属性（直接存储，与iNtkRequest使用习惯一致）

    /// 请求参数，可直接修改
    public var parameters: [String: Sendable]?

    /// 请求头，可直接修改
    public var headers: [String: String]?

    /// 额外数据存储，用于在拦截器间传递自定义信息
    public var extraData: [String: Sendable] = [:]

    // MARK: - 初始化

    /// 使用原始请求初始化可变请求包装器
    /// - Parameter request: 原始请求对象
    public init(_ request: iNtkRequest) {
        self.originalRequest = request
        // 复制原始请求的参数和头部到可变属性中
        self.parameters = request.parameters
        self.headers = request.headers
    }

    // MARK: - iNtkRequest 协议实现

    public var baseURL: URL? {
        return originalRequest.baseURL
    }

    public var path: String {
        return originalRequest.path
    }

    public var method: NtkHTTPMethod {
        return originalRequest.method
    }

    public var timeout: TimeInterval {
        return originalRequest.timeout
    }

    public var requestConfiguration: NtkRequestConfiguration? {
        return originalRequest.requestConfiguration
    }

    // MARK: - 便捷方法

    /// 添加单个请求参数
    /// - Parameters:
    ///   - key: 参数键
    ///   - value: 参数值
    public mutating func addParameter(key: String, value: Sendable) {
        if parameters == nil {
            parameters = [:]
        }
        parameters?[key] = value
    }

    /// 批量添加请求参数
    /// - Parameter parameters: 要添加的参数字典
    public mutating func addParameters(_ parameters: [String: Sendable]) {
        if self.parameters == nil {
            self.parameters = [:]
        }
        self.parameters?.merge(parameters) { _, new in new }
    }

    /// 直接全量替换参数
    ///
    /// 可以方便在拦截器里调整入参的数据结构层级。
    /// - Parameter newParameters: 新的参数
    /// - Note: 需要注意自己处理NtkMutableRequest.parameters原来的参数，这里会被直接全部替换掉。
    public mutating func setParameter(_ newParameters: [String: Sendable]) {
        parameters = newParameters
    }

    /// 添加单个请求头
    /// - Parameters:
    ///   - key: 头部键
    ///   - value: 头部值
    public mutating func addHeader(key: String, value: String) {
        if headers == nil {
            headers = [:]
        }
        headers?[key] = value
    }

    /// 批量添加请求头
    /// - Parameter headers: 要添加的头部字典
    public mutating func addHeaders(_ newHeaders: [String: String]) {
        if headers == nil {
            headers = [:]
        }
        headers?.merge(newHeaders) { _, new in new }
    }

    /// 移除指定的请求参数
    /// - Parameter key: 要移除的参数键
    public mutating func removeParameter(key: String) {
        parameters?.removeValue(forKey: key)
    }

    /// 移除指定的请求头
    /// - Parameter key: 要移除的头部键
    public mutating func removeHeader(key: String) {
        headers?.removeValue(forKey: key)
    }

    /// 清空所有参数
    public mutating func clearParameters() {
        parameters = nil
    }

    /// 清空所有头部
    public mutating func clearHeaders() {
        headers = nil
    }
}

// MARK: - 下标访问支持

extension NtkMutableRequest {

    /// 通过下标访问 extraData 字典
    /// - Parameter key: 键名
    /// - Returns: 对应的值
    public subscript(key: String) -> Sendable? {
        get {
            return extraData[key]
        }
        set {
            extraData[key] = newValue
        }
    }
}

// MARK: - 调试支持

extension NtkMutableRequest: CustomStringConvertible {

    public var description: String {
        return """
            NtkMutableRequest {
                baseURL: \(baseURL?.absoluteString ?? "nil")
                path: \(path)
                method: \(method)
                parameters: \(parameters ?? [:])
                headers: \(headers ?? [:])
                extraData: \(extraData)
            }
            """
    }
}
