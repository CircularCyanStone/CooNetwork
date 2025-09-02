//
//  NtkNetworkCache.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation
import CryptoKit


/// 网络缓存管理器
/// 负责网络请求的缓存存储、读取和管理
@NtkActor
public class NtkNetworkCache {
    /// 关联的网络请求
    public let request: NtkMutableRequest
    /// 缓存存储实现
    public let storage: iNtkCacheStorage
    /// 缓存策略配置
    public let cacheConfig: NtkRequestConfiguration?
    
    /// 初始化网络缓存管理器
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - storage: 缓存存储实现
    public init(request: NtkMutableRequest, storage: iNtkCacheStorage) {
        self.request = request
        self.storage = storage
        self.cacheConfig = request.requestConfiguration
    }
    
    /// 构建缓存键
    /// 根据请求信息和缓存配置生成唯一的缓存键
    /// - Returns: 缓存键字符串
    private func createCacheKey() -> String {
        return NtkRequestIdentifierManager.shared.getCacheKey(request: request, cacheConfig: cacheConfig)
    }
    
    /// 检查是否存在缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasData() -> Bool {
        let cacheKey = createCacheKey()
        return storage.hasData(key: cacheKey)
    }
    
    /// 加载缓存数据
    /// 读取与当前请求关联的缓存数据，会检查缓存是否过期
    /// - Returns: 缓存的数据，如果没有缓存或已过期则返回nil
    /// - Throws: 缓存读取过程中的错误
    public func loadData() async throws -> (any Sendable)? {
        let cacheKey = createCacheKey()
        guard let cacheMetaData = await storage.getData(key: cacheKey) else {
            return nil
        }
        
        if cacheMetaData.expirationDate < Date().timeIntervalSince1970 {
            // 缓存已过期
            return nil
        }
        return cacheMetaData.data
    }
    
    /// 保存数据到缓存
    /// - Parameter data: 要缓存的接口返回数据
    /// - Returns: 保存是否成功
    public func save(data: Sendable) async -> Bool {
        let cacheKey = createCacheKey()
        return await _save(data: data, key: cacheKey)
    }
    
    /// 内部保存方法
    /// 创建缓存元数据并保存到存储器
    /// - Parameters:
    ///   - data: 要缓存的数据
    ///   - key: 缓存键
    /// - Returns: 保存是否成功
    private func _save(data: Sendable, key: String) async -> Bool {
        guard let config = cacheConfig else {
            return false
        }
        
        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let createTime = Date().timeIntervalSince1970
        let expirationDate = createTime + config.cacheTime
        let metaData = NtkCacheMeta(appVersion: versionName, creationDate: createTime, expirationDate: expirationDate, data: data)
        
        return await storage.setData(metaData: metaData, key: key)
    }
}
