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
    /// 缓存存储实现
    public let storage: iNtkCacheStorage
    
    /// 初始化网络缓存管理器
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - storage: 缓存存储实现
    public init(storage: iNtkCacheStorage) {
        self.storage = storage
    }
    
    /// 构建缓存键
    /// 根据请求信息和缓存配置生成唯一的缓存键
    /// - Returns: 缓存键字符串
    private func createCacheKey(for request: NtkMutableRequest) -> String {
        return NtkRequestIdentifierManager.shared.getCacheKey(request: request, cacheConfig: request.requestConfiguration)
    }
    
    /// 检查是否存在缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasData(for request: NtkMutableRequest) async -> Bool {
        let cacheKey = createCacheKey(for: request)
        return await storage.hasData(key: cacheKey)
    }
    
    /// 加载缓存数据
    /// 读取与当前请求关联的缓存数据，会检查缓存是否过期
    /// - Returns: 缓存的数据，如果没有缓存或已过期则返回nil
    /// - Throws: 缓存读取过程中的错误
    public func loadData(for request: NtkMutableRequest) async throws -> (any Sendable)? {
        let cacheKey = createCacheKey(for: request)
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
    public func save(data: Sendable, for request: NtkMutableRequest) async -> Bool {
        guard let requestConfiguration = request.requestConfiguration else { return false }
        let cacheKey = createCacheKey(for: request)
        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let createTime = Date().timeIntervalSince1970
        let expirationDate = createTime + requestConfiguration.cacheTime
        let metaData = NtkCacheMeta(appVersion: versionName, creationDate: createTime, expirationDate: expirationDate, data: data)
        
        return await storage.setData(metaData: metaData, key: cacheKey)
    }
}
