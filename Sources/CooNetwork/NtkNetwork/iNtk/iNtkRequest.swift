//
//  iNtkRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

// iNtkRequestPolicy协议在同一模块中定义

/// HTTP请求方法类型
/// 封装了常用的HTTP方法，支持OC互操作
public enum NtkHTTPMethod: String, RawRepresentable, Sendable, CaseIterable {
    /// `CONNECT` method.
    case connect = "CONNECT"
    /// `DELETE` method.
    case delete = "DELETE"
    /// `GET` method.
    case get = "GET"
    /// `HEAD` method.
    case head = "HEAD"
    /// `OPTIONS` method.
    case options = "OPTIONS"
    /// `PATCH` method.
    case patch = "PATCH"
    /// `POST` method.
    case post = "POST"
    /// `PUT` method.
    case put = "PUT"
    /// `QUERY` method.
    case query = "QUERY"
    /// `TRACE` method.
    case trace = "TRACE"
}

/// 网络请求协议
/// 定义了网络请求的基本属性和行为
public protocol iNtkRequest: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    
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
    
    /// 请求策略配置
    /// - Returns: 请求策略配置，包含缓存和参数过滤设置，如果为nil则不使用缓存和参数过滤
    /// - Note: 该策略用于请求去重时的参数过滤以及缓存键生成
    var requestConfiguration: NtkRequestConfiguration? { get }

    /// 请求级响应缓存配置。
    ///
    /// `nil` 表示不读取也不写入缓存。该配置只控制缓存有效期和响应写入资格，不负责过滤
    /// 请求身份；`cacheTime` 与 `shouldCache` 都不会改变资源 key。无效有效期只关闭缓存，
    /// 网络请求仍继续执行。
    var cacheConfiguration: NtkCacheConfiguration? { get }

    /// 请求级身份策略。
    ///
    /// `nil` 继承 executor 创建时冻结的全局策略；非 `nil` 完整替换全局策略而不合并。
    /// 策略只影响缓存键与去重键，不改变真实请求。排除鉴权字段时必须通过稳定字段或
    /// identity component 保留业务主体隔离，避免跨 user/tenant 共享结果。
    var requestIdentityPolicy: NtkRequestIdentityPolicy? { get }
    
}

public extension iNtkRequest {
    
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
    
    /// 默认超时时间，使用全局配置
    var timeout: TimeInterval {
        NtkConfiguration.current.builder.defaultTimeout
    }
    
    /// 默认请求策略配置为空
    /// 可以通过以下方式自定义策略：
    /// 1. 使用NtkRequestConfiguration.default()获取默认配置
    /// 2. 使用NtkRequestConfiguration.custom(duration:)自定义缓存时间
    /// 3. 不需要缓存或参数过滤时返回 nil
    /// 4. 如需显式禁用缓存，可使用 NtkRequestConfiguration(cacheTime: 0)
    var requestConfiguration: NtkRequestConfiguration? {
        nil
    }

    /// 默认不启用响应缓存，因此不会读取或写入缓存。
    ///
    /// 身份字段过滤由 `requestIdentityPolicy` 或字段参与标记负责；缓存时长和写入资格不会
    /// 改变资源 key。网络请求不受该默认值影响。
    var cacheConfiguration: NtkCacheConfiguration? {
        nil
    }

    /// 默认继承 executor 创建时冻结的全局身份策略。
    ///
    /// 请求返回非 `nil` 时会完整替换全局策略。排除鉴权字段前必须确保稳定的 user/tenant
    /// 隔离仍参与身份；策略处理失败只应关闭本次缓存和去重，网络继续。
    var requestIdentityPolicy: NtkRequestIdentityPolicy? {
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
