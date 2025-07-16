//
//  NtkCacheConfig.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

// iNtkResponse协议在同一模块中定义

/**
 * 缓存配置
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */
protocol iNtkCachePolicy: Sendable {
    
    // 缓存时间（毫秒）
    var cacheTime: TimeInterval { get }
    
    // 参数过滤器
    func filterParameter(_ parameter: [String: Any]) -> [String: Any]
    
    // 自定义缓存策略，默认返回true。
    func customPolicy(_: any iNtkResponse) -> Bool
    
}
extension iNtkCachePolicy {
    var cacheTime: TimeInterval {
        0
    }
    
    func filterParameter(_ parameter: [String: Any]) -> [String: Any] {
        parameter
    }
    
    func customPolicy(_: any iNtkResponse) -> Bool {
        true
    }
}

/**
 * 默认缓存配置实现
 * 支持通过构造函数自定义缓存参数和策略
 */
struct NtkDefaultCachePolicy: iNtkCachePolicy {
    
    private let _cacheTime: TimeInterval
    private let _filterParameter: (@Sendable ([String: Sendable]) -> [String: Sendable])?
    private let _customPolicy: (@Sendable (any iNtkResponse) -> Bool)?
    
    /// 缓存时间（秒）
    var cacheTime: TimeInterval {
        _cacheTime
    }
    
    /**
     * 初始化缓存配置
     * - Parameters:
     *   - cacheTime: 缓存时间（秒），默认为0（不缓存）
     *   - filterParameter: 参数过滤器，用于过滤不参与缓存键生成的参数
     *   - customPolicy: 自定义缓存策略，用于判断响应是否应该被缓存
     */
    init(
        cacheTime: TimeInterval = 0,
        filterParameter: (@Sendable ([String: Sendable]) -> [String: Sendable])? = nil,
        customPolicy: (@Sendable (any iNtkResponse) -> Bool)? = nil
    ) {
        self._cacheTime = cacheTime
        self._filterParameter = filterParameter
        self._customPolicy = customPolicy
    }
    
    func filterParameter(_ parameter: [String: Sendable]) -> [String: Sendable] {
        return _filterParameter?(parameter) ?? parameter
    }
    
    func customPolicy(_ response: any iNtkResponse) -> Bool {
        return _customPolicy?(response) ?? true
    }
}
