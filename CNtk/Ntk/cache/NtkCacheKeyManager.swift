//
//  NtkCacheKeyManager.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation
import CryptoKit

/// 缓存键管理器
/// 基于内存的缓存键复用管理，提供线程安全的缓存键生成和管理功能
/// 使用LRU策略管理内存缓存，避免重复计算相同请求的缓存键
@NtkActor
class NtkCacheKeyManager {
    /// 单例实例
    static var shared: NtkCacheKeyManager = NtkCacheKeyManager()
    /// 内存缓存映射表（LRU容量限制为100）
    private var cacheMap: [String: String] = [:]
    
    /// 获取缓存键
    /// 线程安全地获取请求对应的缓存键，优先从内存缓存中获取，未命中时生成新的缓存键
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存策略配置
    /// - Returns: 唯一的缓存键字符串
    func getCacheKey(request: iNtkRequest, cacheConfig: iNtkCachePolicy?) -> String {
        let serialized = serializeRequest(request: request, cacheConfig: cacheConfig)
        
        // 内存缓存命中
        if let cachedKey = cacheMap[serialized] {
            return cachedKey
        }
        
        // 计算新缓存键
        let newKey = generateKey(serialized: serialized)
        updateCache(key: serialized, value: newKey)
        return newKey
    }
    
    /// 序列化请求参数
    /// 将请求的关键信息序列化为字符串，用于生成缓存键
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存策略配置
    /// - Returns: 序列化后的请求信息字符串
    private func serializeRequest(request: iNtkRequest, cacheConfig: iNtkCachePolicy?) -> String {
        var parameter: Any = ""
        if let params = request.parameters {
            if let config = cacheConfig {
                parameter = config.filterParameter(params)
            } else {
                parameter = params
            }
        }
        let configKey = cacheConfig != nil ? "\(cacheConfig!.cacheTime)" : ""
        return "method:\(request.method.rawValue)|url:\(String(describing: request.baseURL?.appendingPathComponent(request.path).absoluteString))|args:\(parameter)|config:\(configKey)"
    }
    
    /// 生成哈希键
    /// 使用MD5算法对序列化字符串生成哈希值作为缓存键
    /// - Parameter serialized: 序列化后的请求信息字符串
    /// - Returns: MD5哈希值的十六进制字符串
    private func generateKey(serialized: String) -> String {
        let data = Data(serialized.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
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
