//
//  NtkRequestIdentifierManager.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2
//

import Foundation

/// 请求标识符管理器
/// 基于内存的请求标识符复用管理，提供线程安全的请求唯一标识生成和管理功能
/// 用于缓存键生成和请求去重标识，使用LRU策略管理内存缓存，避免重复计算相同请求的标识符
@NtkActor
class NtkRequestIdentifierManager {
    /// 单例实例
    static var shared: NtkRequestIdentifierManager = NtkRequestIdentifierManager()
    /// 内存缓存映射表（LRU容量限制为100）
    private var cacheMap: [String: String] = [:]
    
    /// 获取缓存键
    /// 线程安全地获取请求对应的缓存键，优先从内存缓存中获取，未命中时生成新的缓存键
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存策略配置
    /// - Returns: 唯一的缓存键字符串
    func getCacheKey(request: any iNtkRequest, cacheConfig: iNtkCachePolicy?) -> String {
        let hashValue = generateHashForCache(request: request, cacheConfig: cacheConfig)
        let cacheKey = String(hashValue)
        
        // 对于缓存键，仍使用LRU缓存以避免重复计算
        let serialized = "\(hashValue)" // 使用哈希值作为缓存键
        if let cachedKey = cacheMap[serialized] {
            return cachedKey
        }
        
        updateCache(key: serialized, value: cacheKey)
        return cacheKey
    }
    
    /// 生成请求去重哈希值
    /// 使用Swift Hasher直接对请求组件进行哈希，避免字符串拼接和MD5计算的开销
    /// - Parameter request: 网络请求对象
    /// - Returns: 哈希值
    private func generateHashForDeduplication(request: any iNtkRequest) -> Int {
        var hasher = Hasher()
        
        // HTTP方法
        hasher.combine(request.method.rawValue)
        
        // URL
        if let baseURL = request.baseURL {
            hasher.combine(baseURL.absoluteString)
        }
        hasher.combine(request.path)
        
        // 参数哈希（保持排序以确保一致性）
        if let parameters = request.parameters {
            let sortedKeys = parameters.keys.sorted()
            for key in sortedKeys {
                hasher.combine(key)
                if let value = parameters[key] {
                    hasher.combine("\(value)")
                }
            }
        }
        
        // Headers哈希（排除动态headers）
        if let headers = request.headers {
            let sortedKeys = headers.keys.sorted()
            for key in sortedKeys {
                if !isDynamicHeader(key) {
                    hasher.combine(key)
                    hasher.combine(headers[key] ?? "")
                }
            }
        }
        
        return hasher.finalize()
    }
    
    /// 生成缓存哈希值
    /// 使用Swift Hasher为缓存键生成哈希，包含缓存配置信息
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存策略配置
    /// - Returns: 哈希值
    private func generateHashForCache(request: any iNtkRequest, cacheConfig: iNtkCachePolicy?) -> Int {
        var hasher = Hasher()
        
        // HTTP方法
        hasher.combine(request.method.rawValue)
        
        // URL
        if let baseURL = request.baseURL {
            hasher.combine(baseURL.absoluteString)
        }
        hasher.combine(request.path)
        
        // 参数哈希
        if let parameters = request.parameters {
            if let config = cacheConfig {
                let filteredParams = config.filterParameter(parameters)
                let sortedKeys = (filteredParams as? [String: Any])?.keys.sorted() ?? []
                for key in sortedKeys {
                    hasher.combine(key)
                    if let value = (filteredParams as? [String: Any])?[key] {
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
    
    /// 序列化请求用于去重标识（已弃用，保留用于向后兼容）
    /// 生成用于请求去重的序列化字符串，不包含缓存配置信息
    /// - Parameter request: 网络请求对象
    /// - Returns: 序列化后的字符串
    @available(*, deprecated, message: "Use generateHashForDeduplication instead for better performance")
    private func serializeRequestForDeduplication(request: any iNtkRequest) -> String {
        var components: [String] = []
        
        // HTTP方法
        components.append(request.method.rawValue)
        
        // URL
        if let baseURL = request.baseURL {
            components.append(baseURL.absoluteString)
        }
        components.append(request.path)
        
        // 参数序列化
        if let parameters = request.parameters {
            let sortedKeys = parameters.keys.sorted()
            for key in sortedKeys {
                if let value = parameters[key] {
                    components.append("\(key)=\(value)")
                }
            }
        }
        
        // Headers序列化（排除动态headers如时间戳等）
        if let headers = request.headers {
            let sortedKeys = headers.keys.sorted()
            for key in sortedKeys {
                // 排除可能影响去重的动态header
                if !isDynamicHeader(key) {
                    components.append("\(key)=\(headers[key] ?? "")")
                }
            }
        }
        
        return components.joined(separator: "&")
    }
    
    /// 判断是否为动态Header
    /// - Parameter headerKey: Header键名
    /// - Returns: 是否为动态Header
    private func isDynamicHeader(_ headerKey: String) -> Bool {
        return NtkDeduplicationConfig.shared.isDynamicHeader(headerKey)
    }
    
    /// 获取请求去重标识符
    /// 线程安全地获取请求对应的去重标识符，用于识别相同的请求
    /// - Parameter request: 网络请求对象
    /// - Returns: 唯一的请求标识符字符串
    func getRequestIdentifier(request: any iNtkRequest) -> String {
        let hashValue = generateHashForDeduplication(request: request)
        let identifier = String(hashValue)
        return identifier
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
