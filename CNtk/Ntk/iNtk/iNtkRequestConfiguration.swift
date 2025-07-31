//
//  NtkCacheConfig.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

// iNtkResponse协议在同一模块中定义

/// 参数过滤协议
/// 定义了请求头和请求参数的过滤规则，用于缓存键生成和请求去重
protocol iNtkParameterFilter: Sendable {
    /// 过滤不参与缓存键生成的请求头
    /// - Parameter headers: 原始请求头字典
    /// - Returns: 过滤后的请求头字典
    func filterHeaders(_ headers: [String: String]) -> [String: String]
    
    /// 过滤不参与缓存键生成的请求参数
    /// - Parameter parameters: 原始参数字典
    /// - Returns: 过滤后的参数字典
    func filterParameters(_ parameters: [String: Sendable]) -> [String: Sendable]
}

/// 请求配置协议
/// 定义了网络请求的缓存配置和参数过滤行为
protocol iNtkRequestConfiguration: iNtkParameterFilter {
    
    /// 缓存时间（秒）
    /// - Returns: 缓存有效期，0表示不缓存
    var cacheTime: TimeInterval { get }
    
    /// 自定义缓存策略
    /// 用于判断响应是否应该被缓存
    /// - Parameter response: 网络响应对象
    /// - Returns: 是否应该缓存此响应，默认返回true
    func cachePolicy(_: any iNtkResponse) -> Bool
    
}
// MARK: - 默认实现
extension iNtkParameterFilter {
    /// 默认不过滤任何请求头
    func filterHeaders(_ headers: [String: String]) -> [String: String] {
        return headers
    }
    
    /// 默认不过滤任何请求参数
    func filterParameters(_ parameters: [String: Sendable]) -> [String: Sendable] {
        return parameters
    }
}

extension iNtkRequestConfiguration {
    /// 默认缓存时间为0（不缓存）
    var cacheTime: TimeInterval {
        0
    }
    
    /// 默认参数过滤器，不过滤任何参数（向后兼容）
    /// - Parameter parameter: 原始请求参数
    /// - Returns: 未过滤的原始参数
    func filterParameter(_ parameter: [String: Sendable]) -> [String: Sendable] {
        return filterParameters(parameter)
    }
    
    /// 默认缓存策略，总是缓存
    /// - Parameter response: 网络响应对象
    /// - Returns: 总是返回true
    func cachePolicy(_: any iNtkResponse) -> Bool {
        true
    }
}

/// 默认请求配置实现
/// 支持通过构造函数自定义缓存参数和过滤策略
struct NtkDefaultRequestConfiguration: iNtkRequestConfiguration {
    
    /// 私有缓存时间存储
    private let _cacheTime: TimeInterval
    /// 私有请求头过滤器存储
    private let _filterHeaders: (@Sendable ([String: String]) -> [String: String])?
    /// 私有参数过滤器存储
    private let _filterParameters: (@Sendable ([String: Sendable]) -> [String: Sendable])?
    /// 私有参数过滤器存储（向后兼容）
    private let _filterParameter: (@Sendable ([String: Sendable]) -> [String: Sendable])?
    /// 私有自定义策略存储
    private let _customPolicy: (@Sendable (any iNtkResponse) -> Bool)?
    
    /// 缓存时间（秒）
    /// - Returns: 配置的缓存有效期
    var cacheTime: TimeInterval {
        _cacheTime
    }
    
    /// 初始化缓存配置
    /// - Parameters:
    ///   - cacheTime: 缓存时间（秒）
    ///   - filterHeaders: 请求头过滤器，用于过滤不参与缓存键生成的请求头
    ///   - filterParameters: 参数过滤器，用于过滤不参与缓存键生成的参数
    ///   - filterParameter: 参数过滤器（向后兼容），用于过滤不参与缓存键生成的参数
    ///   - customPolicy: 自定义缓存策略，用于判断响应是否应该被缓存
    init(
        cacheTime: TimeInterval,
        filterHeaders: (@Sendable ([String: String]) -> [String: String])? = nil,
        filterParameters: (@Sendable ([String: Sendable]) -> [String: Sendable])? = nil,
        filterParameter: (@Sendable ([String: Sendable]) -> [String: Sendable])? = nil,
        customPolicy: (@Sendable (any iNtkResponse) -> Bool)? = nil
    ) {
        self._cacheTime = cacheTime
        self._filterHeaders = filterHeaders
        self._filterParameters = filterParameters
        self._filterParameter = filterParameter
        self._customPolicy = customPolicy
    }
    
    /// 过滤请求头
    /// - Parameter headers: 原始请求头字典
    /// - Returns: 过滤后的请求头字典，如果没有自定义过滤器则返回原请求头
    func filterHeaders(_ headers: [String: String]) -> [String: String] {
        return _filterHeaders?(headers) ?? headers
    }
    
    /// 过滤请求参数
    /// - Parameter parameters: 原始参数字典
    /// - Returns: 过滤后的参数字典，如果没有自定义过滤器则返回原参数
    func filterParameters(_ parameters: [String: Sendable]) -> [String: Sendable] {
        return _filterParameters?(parameters) ?? parameters
    }
    
    /// 过滤请求参数（向后兼容）
    /// - Parameter parameter: 原始请求参数
    /// - Returns: 过滤后的参数，如果没有自定义过滤器则返回原参数
    func filterParameter(_ parameter: [String: Sendable]) -> [String: Sendable] {
        return _filterParameter?(parameter) ?? parameter
    }
    
    /// 执行自定义缓存策略
    /// - Parameter response: 网络响应对象
    /// - Returns: 是否应该缓存此响应，如果没有自定义策略则返回true
    func cachePolicy(_ response: any iNtkResponse) -> Bool {
        return _customPolicy?(response) ?? true
    }
}
