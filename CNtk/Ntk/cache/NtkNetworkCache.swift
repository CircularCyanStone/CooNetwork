//
//  NtkNetworkCache.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation
import CryptoKit

// 导入网络组件协议
// 注意：实际使用时需要确保这些文件在正确的模块路径下
// 这里假设它们在同一个项目中，可以直接访问

/**
 * Ntk网络工具缓存工具
 * 抽象逻辑
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */
class NtkNetworkCache {
    // 请求
    let request: iNtkRequest
    // 缓存能力工具
    let storage: NtkCacheStorage
    // 缓存配置
    let cacheConfig: NtkCacheConfig?
    
    init(request: iNtkRequest, storage: NtkCacheStorage, cacheConfig: NtkCacheConfig? = nil) {
        self.request = request
        self.storage = storage
        self.cacheConfig = cacheConfig
    }
    
    /**
     * 构建缓存时key
     * @returns key
     */
    private func createCacheKey() -> String {
        return NtkCacheKeyManager.shared.getCacheKey(request: request, cacheConfig: cacheConfig)
    }
    
    private func createCacheKeySync() -> String {
        var parameter: Any = ""
        if let params = request.parameters {
            if let config = cacheConfig, let filter = config.filterParameter {
                parameter = filter(params)
            } else {
                parameter = params
            }
        }
        
        let keyInfo = "method:\(request.method.rawValue)|url:\(request.baseURL.appendingPathComponent(request.path).absoluteString)|args:\(parameter)"
        let data = Data(keyInfo.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /**
     * 返回该请求是否有缓存数据
     * @returns
     */
    func hasData() -> Bool {
        let cacheKey = createCacheKeySync()
        return storage.hasData(key: cacheKey)
    }
    
    /**
     * 读取request关联的缓存数据
     */
    func loadData() async -> Any? {
        let cacheKey = createCacheKey()
        guard let cacheData = await storage.getData(key: cacheKey) else {
            return nil
        }
        
        if cacheData.expirationDate < Date().timeIntervalSince1970 * 1000 {
            // 过期了
            return nil
        }
        return cacheData.data
    }
    
    /**
     * 缓存接口数据
     * @param data 接口返回的数据
     */
    func save(data: Any) async -> Bool {
        let cacheKey = createCacheKey()
        return await _save(data: data, key: cacheKey)
    }
    
    private func _save(data: Any, key: String) async -> Bool {
        guard let config = cacheConfig else {
            return false
        }
        
        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let createTime = Date().timeIntervalSince1970 * 1000
        let expirationDate = createTime + config.cacheTime
        let metaData = NtkCacheMeta(appVersion: versionName, creationDate: createTime, expirationDate: expirationDate, data: data)
        
        return await storage.setData(metaData: metaData, key: key)
    }
}
