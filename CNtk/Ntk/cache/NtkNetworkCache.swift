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

@NtkActor
class NtkNetworkCache<Keys: NtkResponseMapKeys> {
    // 请求
    let request: iNtkRequest
    // 缓存能力工具
    let storage: iNtkCacheStorage
    // 缓存配置
    let cacheConfig: iNtkCachePolicy?
    
    init(request: iNtkRequest, storage: iNtkCacheStorage) {
        self.request = request
        self.storage = storage
        self.cacheConfig = request.cachePolicy
    }
    
    /**
     * 构建缓存时key
     * @returns key
     */
    private func createCacheKey() -> String {
        return NtkCacheKeyManager.shared.getCacheKey(request: request, cacheConfig: cacheConfig)
    }
    
    /**
     * 返回该请求是否有缓存数据
     * @returns
     */
    func hasData() -> Bool {
        let cacheKey = createCacheKey()
        return storage.hasData(key: cacheKey)
    }
    
    /**
     * 读取request关联的缓存数据
     */
    func loadData() async throws -> (any Sendable)? {
        let cacheKey = createCacheKey()
        guard let cacheMetaData = await storage.getData(key: cacheKey) else {
            return nil
        }
        
        if cacheMetaData.expirationDate < Date().timeIntervalSince1970 * 1000 {
            // 过期了
            return nil
        }
        return cacheMetaData.data
    }
    
    /**
     * 缓存接口数据
     * @param data 接口返回的数据
     */
    func save(data: Sendable) async -> Bool {
        let cacheKey = createCacheKey()
        return await _save(data: data, key: cacheKey)
    }
    
    private func _save(data: Sendable, key: String) async -> Bool {
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
