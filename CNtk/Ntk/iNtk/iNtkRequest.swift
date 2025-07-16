//
//  iNtkRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

// iNtkCacheConfig协议在同一模块中定义

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

    let rawValue: String

    required init(rawValue: String) {
        self.rawValue = rawValue
    }
}

protocol iNtkRequest: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    
    var baseURL: URL? { get }
    
    var path: String { get }
    
    var method: NtkHTTPMethod { get }
    
    var headers: [String: String]? { get }
    
    /// 接口参数
    var parameters: [String: Sendable]? { get }
    
    var timeout: TimeInterval { get }
    
    var cachePolicy: iNtkCachePolicy? { get }
    
}

extension iNtkRequest {
    
    var baseURL: URL? {
        nil
    }
    
    var method: NtkHTTPMethod {
        .post
    }
    
    var headers: [String: String]? {
        nil
    }
    
    /// 接口参数
    var parameters: [String: Sendable]? {
        nil
    }
    
    var timeout: TimeInterval {
        20
    }
    
    // 缓存策略。
    // 1. 直接在iNtkRequest的实现类内部定义内嵌类型。
    // 2. 使用默认实现。
    var cachePolicy: iNtkCachePolicy? {
        nil
    }
    
    // MARK: - CustomStringConvertible
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

