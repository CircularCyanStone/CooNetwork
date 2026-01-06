//
//  NtkRequestConfiguration.swift
//  NtkNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

/// Ntk请求配置结构体
/// 替代iNtkRequestConfiguration协议，提供更简洁的配置方式
public struct NtkRequestConfiguration: Sendable {
    /// 缓存时间（秒）
    public let cacheTime: TimeInterval
    
    /// 需要过滤的参数名称列表（不区分大小写）
    /// 这些参数不会参与缓存键的生成
    public let filteredParameterNames: [String]
    
    /// 请求头过滤器
    /// 用于过滤不参与缓存键生成的请求头
    public let filterHeaders: @Sendable ([String: String]) -> [String: String]
    
    /// 请求参数过滤器
    /// 用于过滤不参与缓存键生成的请求参数
    public let filterParameters: @Sendable ([String: Sendable]) -> [String: Sendable]
    
    /// 缓存策略
    /// 用于判断响应是否应该被缓存
    public let shouldCache: @Sendable (any iNtkResponse) -> Bool
    
    /// 初始化请求配置
    /// - Parameters:
    ///   - cacheTime: 缓存时间（秒），0表示不缓存
    ///   - filteredParameterNames: 需要过滤的参数名称列表
    ///   - filterHeaders: 请求头过滤器
    ///   - filterParameters: 请求参数过滤器
    ///   - shouldCache: 缓存策略判断器
    public init(
        cacheTime: TimeInterval,
        filteredParameterNames: [String] = ["token"],
        filterHeaders: (@Sendable ([String: String]) -> [String: String])? = nil,
        filterParameters: (@Sendable ([String: Sendable]) -> [String: Sendable])? = nil,
        shouldCache: @escaping @Sendable (any iNtkResponse) -> Bool = { _ in true }
    ) {
        self.cacheTime = cacheTime
        self.filteredParameterNames = filteredParameterNames
        
        // 如果没有提供自定义过滤器，使用基于filteredParameterNames的默认过滤器
        if let filterHeaders = filterHeaders {
            self.filterHeaders = filterHeaders
        } else {
            self.filterHeaders = { headers in
                return headers.filter { key, _ in
                    !filteredParameterNames.contains { filterName in
                        key.lowercased().contains(filterName.lowercased())
                    }
                }
            }
        }
        
        if let filterParameters = filterParameters {
            self.filterParameters = filterParameters
        } else {
            self.filterParameters = { parameters in
                return parameters.filter { key, _ in
                    !filteredParameterNames.contains { filterName in
                        key.lowercased().contains(filterName.lowercased())
                    }
                }
            }
        }
        
        self.shouldCache = shouldCache
    }
}

// MARK: - 默认配置
extension NtkRequestConfiguration {
    
    /// 默认配置
    /// 缓存时间30天，过滤token字段（不区分大小写），其他不做处理
    /// - Returns: 默认的请求配置
    public static func `default`() -> NtkRequestConfiguration {
        return NtkRequestConfiguration(
            cacheTime: 30 * 24 * 60 * 60, // 30天
            filteredParameterNames: ["token"]
        )
    }
    
    /// 自定义缓存时间的配置
    /// 使用默认的过滤规则，但自定义缓存时间
    /// - Parameter duration: 缓存时间（秒）
    /// - Returns: 自定义缓存时间的请求配置
    public static func custom(duration: TimeInterval) -> NtkRequestConfiguration {
        return NtkRequestConfiguration(
            cacheTime: duration,
            filteredParameterNames: ["token"]
        )
    }
    
    /// 自定义过滤参数的配置
    /// 使用默认缓存时间（30天），但自定义过滤参数列表
    /// - Parameter filteredParams: 需要过滤的参数名称列表
    /// - Returns: 自定义过滤参数的请求配置
    public static func custom(filteredParams: [String]) -> NtkRequestConfiguration {
        return NtkRequestConfiguration(
            cacheTime: 30 * 24 * 60 * 60, // 30天
            filteredParameterNames: filteredParams
        )
    }
    
    /// 完全自定义的配置
    /// 自定义缓存时间和过滤参数列表
    /// - Parameters:
    ///   - duration: 缓存时间（秒）
    ///   - filteredParams: 需要过滤的参数名称列表
    /// - Returns: 完全自定义的请求配置
    public static func custom(duration: TimeInterval, filteredParams: [String]) -> NtkRequestConfiguration {
        return NtkRequestConfiguration(
            cacheTime: duration,
            filteredParameterNames: filteredParams
        )
    }
}
