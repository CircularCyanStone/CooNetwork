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

    /// 内存缓存：请求特征 → 缓存键
    /// 避免重复计算相同请求的哈希
    private var requestCache: [RequestCacheKey: String] = [:]
    /// LRU 队列：按访问顺序存储缓存键
    private var lruLRUQueue: [RequestCacheKey] = []
    private let maxCacheSize = 100

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
    public func getCacheKey(request: NtkMutableRequest, cacheConfig: NtkRequestConfiguration?) -> String {
        let requestKey = RequestCacheKey(request: request, cacheConfig: cacheConfig)

        // 查询缓存
        if let cached = requestCache[requestKey] {
            // 缓存命中：更新 LRU 队列，移到末尾
            updateLRU(key: requestKey)
            return cached
        }

        // 计算新值
        let hash = generateHashForCache(request: request, cacheConfig: cacheConfig)
        let cacheKey = "cache_\(hash)"

        // 更新缓存（LRU 策略）
        if requestCache.count >= maxCacheSize {
            // 删除最老的条目（队列第一个）
            if let oldestKey = lruLRUQueue.first {
                requestCache.removeValue(forKey: oldestKey)
                lruLRUQueue.removeFirst()
            }
        }
        requestCache[requestKey] = cacheKey
        lruLRUQueue.append(requestKey)

        return cacheKey
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

    /// 更新 LRU 队列
    /// 将访问的键移到队列末尾，表示最近使用
    /// - Parameter key: 访问的缓存键
    private func updateLRU(key: RequestCacheKey) {
        // 如果键已在队列中，先移除
        if let index = lruLRUQueue.firstIndex(where: { $0 == key }) {
            lruLRUQueue.remove(at: index)
        }
        // 添加到末尾（最近使用）
        lruLRUQueue.append(key)
    }

    /// 生成缓存哈希值
    /// 使用MD5为缓存生成稳定哈希，确保相同请求内容始终产生相同的缓存key
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存配置，用于参数过滤
    /// - Returns: 哈希值字符串
    private func generateHashForCache(request: NtkMutableRequest, cacheConfig: NtkRequestConfiguration?) -> String {
        // 使用 MD5 生成稳定哈希
        let components = buildHashComponents(
            request: request,
            config: cacheConfig,
            includeCacheTime: true
        )

        let combinedString = components.joined(separator: "|")
        let data = Data(combinedString.utf8)
        let digest = Insecure.MD5.hash(data: data)

        // 将MD5摘要转换为16进制字符串
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 生成去重哈希值
    /// 使用Swift Hasher为请求去重生成哈希，通过requestConfiguration过滤动态参数
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

        // Headers哈希（通过requestConfiguration过滤动态headers）
        if let headers = request.headers {
            appendFilteredHeaders(to: &hasher, headers: headers, config: request.requestConfiguration)
        }

        // 参数哈希（通过requestConfiguration过滤动态参数）
        if let parameters = request.parameters {
            appendFilteredParameters(to: &hasher, parameters: parameters, config: request.requestConfiguration)
        }

        return hasher.finalize()
    }

    /// 构建哈希组件数组（用于缓存）
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - config: 请求配置，用于参数过滤
    ///   - includeCacheTime: 是否包含缓存时间
    /// - Returns: 哈希组件数组
    private func buildHashComponents(
        request: NtkMutableRequest,
        config: NtkRequestConfiguration?,
        includeCacheTime: Bool
    ) -> [String] {
        var components: [String] = []

        // HTTP方法
        components.append(request.method.rawValue)

        // URL
        if let baseURL = request.baseURL {
            components.append(baseURL.absoluteString)
        }
        components.append(request.path)

        // Headers
        if let headers = request.headers {
            let filtered = config?.filterHeaders(headers) ?? headers
            let sortedKeys = filtered.keys.sorted()
            for key in sortedKeys {
                components.append(key)
                if let value = filtered[key] {
                    components.append("\(value)")
                }
            }
        }

        // Parameters
        if let parameters = request.parameters {
            let filtered = config?.filterParameters(parameters) ?? parameters
            let sortedKeys = filtered.keys.sorted()
            for key in sortedKeys {
                components.append(key)
                if let value = filtered[key] {
                    components.append("\(value)")
                }
            }
        }

        // 缓存时间
        if includeCacheTime, let config = config {
            components.append("\(config.cacheTime)")
        }

        return components
    }

    /// 将过滤后的 Headers 添加到 Hasher（用于去重）
    /// - Parameters:
    ///   - hasher: Hasher 引用
    ///   - headers: 原始 Headers
    ///   - config: 请求配置（用于过滤）
    private func appendFilteredHeaders(
        to hasher: inout Hasher,
        headers: [String: String],
        config: NtkRequestConfiguration?
    ) {
        let filtered = config?.filterHeaders(headers) ?? headers
        let sortedKeys = filtered.keys.sorted()
        for key in sortedKeys {
            hasher.combine(key)
            if let value = filtered[key] {
                hasher.combine(value)
            }
        }
    }

    /// 将过滤后的 Parameters 添加到 Hasher（用于去重）
    /// - Parameters:
    ///   - hasher: Hasher 引用
    ///   - parameters: 原始 Parameters
    ///   - config: 请求配置（用于过滤）
    private func appendFilteredParameters(
        to hasher: inout Hasher,
        parameters: [String: Sendable],
        config: NtkRequestConfiguration?
    ) {
        let filtered = config?.filterParameters(parameters) ?? parameters
        let sortedKeys = filtered.keys.sorted()
        for key in sortedKeys {
            hasher.combine(key)
            if let value = filtered[key] {
                hasher.combine("\(value)")
            }
        }
    }
}

// MARK: - RequestCacheKey

/// 请求缓存键
/// 用于缓存原始请求到缓存键的映射
private struct RequestCacheKey: Hashable {
    let method: String
    let baseURL: String?
    let path: String
    let headers: [String: String]?
    let parameters: [String: String]?  // 转换为字符串以支持 Hashable
    let cacheTime: TimeInterval?

    init(request: NtkMutableRequest, cacheConfig: NtkRequestConfiguration?) {
        self.method = request.method.rawValue
        self.baseURL = request.baseURL?.absoluteString
        self.path = request.path
        self.headers = cacheConfig?.filterHeaders(request.headers ?? [:])

        // 转换参数类型为字符串以支持 Hashable
        if let params = cacheConfig?.filterParameters(request.parameters ?? [:]) {
            var convertedParams: [String: String] = [:]
            for (key, value) in params {
                convertedParams[key] = "\(value)"
            }
            self.parameters = convertedParams
        } else {
            self.parameters = nil
        }
        self.cacheTime = cacheConfig?.cacheTime
    }
}
