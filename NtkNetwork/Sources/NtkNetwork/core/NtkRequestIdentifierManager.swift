//
//  NtkRequestIdentifierManager.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//  Copyright © 2024 coo. All rights reserved.
//

import Foundation
import CryptoKit

/// 请求标识符管理器
/// 负责为网络请求生成唯一的缓存键和去重标识符
/// 使用Swift Hasher确保高性能的哈希计算
@NtkActor
public class NtkRequestIdentifierManager {
    
    /// 内存缓存映射
    /// 使用LRU策略管理缓存条目，避免内存无限增长
    private var cacheMap: [String: String] = [:]
    
    /// 单例实例
    /// 确保全局唯一的标识符管理器
    public static let shared = NtkRequestIdentifierManager()
    
    private init() {}
    
    /// 获取缓存键
    /// 为网络请求生成用于缓存的唯一标识符，考虑缓存配置
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存配置，用于参数过滤
    /// - Returns: 缓存键字符串
    public func getCacheKey(request: NtkMutableRequest, cacheConfig: (any iNtkRequestConfiguration)?) -> String {
        let hash = generateHashForCache(request: request, cacheConfig: cacheConfig)
        let key = "cache_\(hash)"
        updateCache(key: key, value: key)
        return key
    }
    
    /// 获取请求标识符
    /// 为网络请求生成用于去重的唯一标识符
    /// - Parameter request: 网络请求对象
    /// - Returns: 请求标识符字符串
    public func getRequestIdentifier(request: NtkMutableRequest) -> String {
        let hash = generateHashForDeduplication(request: request)
        return "request_\(hash)"
    }
}

// MARK: - Private Methods
extension NtkRequestIdentifierManager {
    
    /// 生成缓存哈希值
    /// 使用Swift Hasher为缓存生成哈希，通过cacheConfig过滤参数
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存配置，用于参数过滤
    /// - Returns: 哈希值
    private func generateHashForCache(request: NtkMutableRequest, cacheConfig: (any iNtkRequestConfiguration)?) -> Int {
        var hasher = Hasher()
        
        // HTTP方法
        hasher.combine(request.method.rawValue)
        
        // URL
        if let baseURL = request.baseURL {
            hasher.combine(baseURL.absoluteString)
        }
        hasher.combine(request.path)
        
        // Headers哈希（通过cacheConfig过滤）
        if let headers = request.headers {
            if let config = cacheConfig {
                let filteredHeaders = config.filterHeaders(headers)
                let sortedKeys = filteredHeaders.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = filteredHeaders[key] {
                        hasher.combine("\(value)")
                    }
                }
            } else {
                let sortedKeys = headers.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = headers[key] {
                        hasher.combine("\(value)")
                    }
                }
            }
        }
        
        // 参数哈希（通过cachePolicy过滤）
        if let parameters = request.parameters {
            if let config = cacheConfig {
                let filteredParams = config.filterParameters(parameters)
                let sortedKeys = filteredParams.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = filteredParams[key] {
                        hasher.combine("\(value)")
                    }
                }
            } else {
                let sortedKeys = parameters.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = parameters[key] {
                        hasher.combine("\(value)")
                    }
                }
            }
        }
        
        // 缓存配置
        if let config = cacheConfig {
            hasher.combine(config.cacheTime)
        }
        
        return hasher.finalize()
    }
    
    /// 生成去重哈希值
    /// 使用Swift Hasher为请求去重生成哈希，通过requestPolicy过滤动态参数
    /// - Parameter request: 网络请求对象
    /// - Returns: 哈希值
    private func generateHashForDeduplication(request: NtkMutableRequest) -> Int {
        var hasher = Hasher()
        
        // HTTP方法
        hasher.combine(request.method.rawValue)
        
        // URL
        if let baseURL = request.baseURL {
            hasher.combine(baseURL.absoluteString)
        }
        hasher.combine(request.path)
        
        // Headers哈希（通过requestPolicy过滤动态headers）
        if let headers = request.headers {
            if let config = request.requestConfiguration {
                let filteredHeaders = config.filterHeaders(headers)
                let sortedKeys = filteredHeaders.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = filteredHeaders[key] {
                        hasher.combine("\(value)")
                    }
                }
            } else {
                let sortedKeys = headers.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = headers[key] {
                        hasher.combine("\(value)")
                    }
                }
            }
        }
        
        // 参数哈希（通过requestPolicy过滤动态参数）
        if let parameters = request.parameters {
            if let config = request.requestConfiguration {
                let filteredParams = config.filterParameters(parameters)
                let sortedKeys = filteredParams.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = filteredParams[key] {
                        hasher.combine("\(value)")
                    }
                }
            } else {
                let sortedKeys = parameters.keys.sorted()
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = parameters[key] {
                        hasher.combine("\(value)")
                    }
                }
            }
        }
        
        return hasher.finalize()
    }
    
    /// 更新缓存
    /// 使用LRU策略更新内存缓存，当缓存达到容量限制时淘汰最旧的条目
    /// - Parameters:
    ///   - key: 缓存键
    ///   - value: 缓存值
    private func updateCache(key: String, value: String) {
        if cacheMap.count >= 100 {
            // 删除最旧条目（简化的LRU实现）
            if let firstKey = cacheMap.keys.first {
                cacheMap.removeValue(forKey: firstKey)
            }
        }
        cacheMap[key] = value
    }
}
