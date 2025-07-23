//
//  NtkCacheConfig.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

// iNtkResponse协议在同一模块中定义

/// 缓存策略协议
/// 定义了网络请求缓存的配置和行为
protocol iNtkCachePolicy: Sendable {
    
    /// 缓存时间（秒）
    /// - Returns: 缓存有效期，0表示不缓存
    var cacheTime: TimeInterval { get }
    
    /// 参数过滤器
    /// 用于过滤不参与缓存键生成的参数
    /// - Parameter parameter: 原始请求参数
    /// - Returns: 过滤后的参数，用于生成缓存键
    func filterParameter(_ parameter: [String: Any]) -> [String: Any]
    
    /// 自定义缓存策略
    /// 用于判断响应是否应该被缓存
    /// - Parameter response: 网络响应对象
    /// - Returns: 是否应该缓存此响应，默认返回true
    func customPolicy(_: any iNtkResponse) -> Bool
    
}
extension iNtkCachePolicy {
    /// 默认缓存时间为0（不缓存）
    var cacheTime: TimeInterval {
        0
    }
    
    /// 默认参数过滤器，不过滤任何参数
    /// - Parameter parameter: 原始请求参数
    /// - Returns: 未过滤的原始参数
    func filterParameter(_ parameter: [String: Any]) -> [String: Any] {
        parameter
    }
    
    /// 默认缓存策略，总是缓存
    /// - Parameter response: 网络响应对象
    /// - Returns: 总是返回true
    func customPolicy(_: any iNtkResponse) -> Bool {
        true
    }
}

/// 默认缓存策略实现
/// 支持通过构造函数自定义缓存参数和策略
struct NtkDefaultCachePolicy: iNtkCachePolicy {
    
    /// 私有缓存时间存储
    private let _cacheTime: TimeInterval
    /// 私有参数过滤器存储
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
    ///   - filterParameter: 参数过滤器，用于过滤不参与缓存键生成的参数
    ///   - customPolicy: 自定义缓存策略，用于判断响应是否应该被缓存
    init(
        cacheTime: TimeInterval,
        filterParameter: (@Sendable ([String: Sendable]) -> [String: Sendable])? = nil,
        customPolicy: (@Sendable (any iNtkResponse) -> Bool)? = nil
    ) {
        self._cacheTime = cacheTime
        self._filterParameter = filterParameter
        self._customPolicy = customPolicy
    }
    
    /// 过滤请求参数
    /// - Parameter parameter: 原始请求参数
    /// - Returns: 过滤后的参数，如果没有自定义过滤器则返回原参数
    func filterParameter(_ parameter: [String: Sendable]) -> [String: Sendable] {
        return _filterParameter?(parameter) ?? parameter
    }
    
    /// 执行自定义缓存策略
    /// - Parameter response: 网络响应对象
    /// - Returns: 是否应该缓存此响应，如果没有自定义策略则返回true
    func customPolicy(_ response: any iNtkResponse) -> Bool {
        return _customPolicy?(response) ?? true
    }
}
