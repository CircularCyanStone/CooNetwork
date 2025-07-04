//
//  NtkCacheKeyManager.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation
import CryptoKit

// 导入相关模块
// 注意：这些import路径可能需要根据实际项目结构调整

/**
 * Ntk缓存键管理工具：基于内存的缓存键复用管理
 *
 *
 * 建议后续步骤：
 * 在 NtkCacheKeyManager 中添加缓存命中率统计
 * 实现更智能的 LRU 淘汰策略（参考 LinkedHashMap）
 * 增加缓存失效机制（如定时刷新）
 */
class NtkCacheKeyManager {
    // 单例实例
    static var shared: NtkCacheKeyManager = NtkCacheKeyManager()
    // 内存缓存（LRU容量建议100）
    private var cacheMap: [String: String] = [:]
    private let queue = DispatchQueue(label: "NtkCacheKeyManager", attributes: .concurrent)
    
    /**
     * 获取缓存键（线程安全）
     */
    func getCacheKey(request: iNtkRequest, cacheConfig: NtkCacheConfig?) -> String {
        let serialized = serializeRequest(request: request, cacheConfig: cacheConfig)
        
        // 内存缓存命中
        let cachedKey = queue.sync {
            return cacheMap[serialized]
        }
        
        if let key = cachedKey {
            return key
        }
        
        // 计算新缓存键
        let newKey = generateKey(serialized: serialized)
        queue.async(flags: .barrier) {
            self.updateCache(key: serialized, value: newKey)
        }
        return newKey
    }
    
    /**
     * 序列化请求参数（私有方法）
     */
    private func serializeRequest(request: iNtkRequest, cacheConfig: NtkCacheConfig?) -> String {
        var parameter: Any = ""
        if let params = request.parameters {
            if let config = cacheConfig {
                parameter = config.filterParameter(params)
            } else {
                parameter = params
            }
        }
        let configKey = cacheConfig != nil ? "\(cacheConfig!.cacheTime)" : ""
        return "method:\(request.method.rawValue)|url:\(request.baseURL.appendingPathComponent(request.path).absoluteString)|args:\(parameter)|config:\(configKey)"
    }
    
    /**
     * 生成哈希键（私有方法）
     */
    private func generateKey(serialized: String) -> String {
        let data = Data(serialized.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /**
     * 更新缓存（带LRU淘汰）
     */
    private func updateCache(key: String, value: String) {
        if cacheMap.count >= 100 {
            // 删除最旧条目（实际生产环境应用更复杂策略）
            if let firstKey = cacheMap.keys.first {
                cacheMap.removeValue(forKey: firstKey)
            }
        }
        cacheMap[key] = value
    }
}
