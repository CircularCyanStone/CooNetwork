//
//  iNtkRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

// iNtkCacheConfig协议在同一模块中定义

/// HTTP请求方法类型
/// 封装了常用的HTTP方法，支持OC互操作
@objcMembers
final class NtkHTTPMethod: NSObject, RawRepresentable, Sendable {
    /// `CONNECT` method.
    static let connect = NtkHTTPMethod(rawValue: "CONNECT")
    /// `DELETE` method.
    static let delete = NtkHTTPMethod(rawValue: "DELETE")
    /// `GET` method.
    static let get = NtkHTTPMethod(rawValue: "GET")
    /// `HEAD` method.
    static let head = NtkHTTPMethod(rawValue: "HEAD")
    /// `OPTIONS` method.
    static let options = NtkHTTPMethod(rawValue: "OPTIONS")
    /// `PATCH` method.
    static let patch = NtkHTTPMethod(rawValue: "PATCH")
    /// `POST` method.
    static let post = NtkHTTPMethod(rawValue: "POST")
    /// `PUT` method.
    static let put = NtkHTTPMethod(rawValue: "PUT")
    /// `QUERY` method.
    static let query = NtkHTTPMethod(rawValue: "QUERY")
    /// `TRACE` method.
    static let trace = NtkHTTPMethod(rawValue: "TRACE")

    /// HTTP方法的原始字符串值
    let rawValue: String

    /// 使用原始字符串值初始化HTTP方法
    /// - Parameter rawValue: HTTP方法的字符串表示
    required init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// 网络请求协议
/// 定义了网络请求的基本属性和行为
protocol iNtkRequest: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    
    /// 请求的基础URL
    /// - Returns: 基础URL，如果为nil则使用全局配置的baseURL
    var baseURL: URL? { get }
    
    /// 请求路径
    /// - Returns: API接口的相对路径
    var path: String { get }
    
    /// HTTP请求方法
    /// - Returns: 请求方法，默认为POST
    var method: NtkHTTPMethod { get }
    
    /// 请求头
    /// - Returns: HTTP请求头字典，可选
    var headers: [String: String]? { get }
    
    /// 请求参数
    /// - Returns: 请求参数字典，支持Sendable类型
    var parameters: [String: Sendable]? { get }
    
    /// 请求超时时间
    /// - Returns: 超时时间（秒），默认20秒
    var timeout: TimeInterval { get }
    
    /// 缓存策略
    /// - Returns: 缓存配置，如果为nil则不使用缓存
    var cachePolicy: iNtkCachePolicy? { get }
    
}

extension iNtkRequest {
    
    /// 默认基础URL为nil
    var baseURL: URL? {
        nil
    }
    
    /// 默认请求方法为POST
    var method: NtkHTTPMethod {
        .post
    }
    
    /// 默认请求头为空
    var headers: [String: String]? {
        nil
    }
    
    /// 默认请求参数为空
    var parameters: [String: Sendable]? {
        nil
    }
    
    /// 默认超时时间为20秒
    var timeout: TimeInterval {
        20
    }
    
    /// 默认缓存策略为空（不缓存）
    /// 可以通过以下方式自定义缓存策略：
    /// 1. 直接在iNtkRequest的实现类内部定义内嵌类型
    /// 2. 使用NtkDefaultCachePolicy默认实现
    var cachePolicy: iNtkCachePolicy? {
        nil
    }
    
    // MARK: - CustomStringConvertible
    /// 请求的简要描述
    /// - Returns: 包含请求基本信息的字符串
    var description: String {
        let url = baseURL?.appendingPathComponent(path).absoluteString ?? path
        let methodStr = method.rawValue
        let timeoutStr = String(format: "%.1f", timeout)
        
        var components = ["\(type(of: self))"]
        components.append("Method: \(methodStr)")
        components.append("URL: \(url)")
        components.append("Timeout: \(timeoutStr)s")
        
        if let headers = headers, !headers.isEmpty {
            components.append("Headers: \(headers.count) items")
        }
        
        if let parameters = parameters, !parameters.isEmpty {
            components.append("Parameters: \(parameters.count) items")
        }
        
        return "<\(components.joined(separator: ", "))>"
    }
    
    // MARK: - CustomDebugStringConvertible
    /// 请求的详细调试描述
    /// - Returns: 包含请求详细信息的字符串，用于调试
    var debugDescription: String {
        let url = baseURL?.appendingPathComponent(path).absoluteString ?? path
        let methodStr = method.rawValue
        let timeoutStr = String(format: "%.1f", timeout)
        
        var components = ["\(type(of: self))"]
        components.append("Method: \(methodStr)")
        components.append("URL: \(url)")
        components.append("Timeout: \(timeoutStr)s")
        
        if let headers = headers {
            if headers.isEmpty {
                components.append("Headers: []")
            } else {
                let headersStr = headers.map { "\"\($0.key)\": \"\($0.value)\"" }.joined(separator: ", ")
                components.append("Headers: [\(headersStr)]")
            }
        } else {
            components.append("Headers: nil")
        }
        
        if let parameters = parameters {
            if parameters.isEmpty {
                components.append("Parameters: [:]")
            } else {
                let paramsStr = parameters.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
                components.append("Parameters: [\(paramsStr)]")
            }
        } else {
            components.append("Parameters: nil")
        }
        
        return "<\(components.joined(separator: "\n  "))>"
    }
    
}

