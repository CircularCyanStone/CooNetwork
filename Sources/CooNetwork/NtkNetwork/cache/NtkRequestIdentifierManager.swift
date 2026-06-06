//
//  NtkRequestIdentifierManager.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//  Copyright © 2024 coo. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - LRU 双向链表

/// LRU 双向链表节点
@usableFromInline
internal final class LRUNode<Key: Hashable, Value> {
    var key: Key
    var value: Value
    weak var prev: LRUNode?
    var next: LRUNode?

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

/// LRU 双向链表
/// 支持 O(1) 的头部插入、移动和尾部删除操作
@usableFromInline
internal final class LRUList<Key: Hashable, Value> {
    private(set) var head: LRUNode<Key, Value>?  // 最近使用
    private(set) var tail: LRUNode<Key, Value>?  // 最久未使用
    private(set) var count: Int = 0

    /// 添加节点到头部（标记为最近使用）
    /// - Parameters:
    ///   - key: 节点键
    ///   - value: 节点值
    /// - Returns: 新创建的节点
    func addFirst(key: Key, value: Value) -> LRUNode<Key, Value> {
        let node = LRUNode(key: key, value: value)

        if head == nil {
            head = node
            tail = node
        } else {
            node.next = head
            head?.prev = node
            head = node
        }

        count += 1
        return node
    }

    /// 将已有节点移动到头部（标记为最近使用）
    /// - Parameter node: 要移动的节点
    func moveToFirst(_ node: LRUNode<Key, Value>) {
        guard node !== head else { return }  // 已经在头部，无需操作

        // 从原位置移除
        remove(node)

        // 插入到头部
        node.next = head
        head?.prev = node
        node.prev = nil
        head = node

        count += 1
    }

    /// 移除并返回尾部节点（最久未使用）
    /// - Returns: 被移除的键值对，如果链表为空则返回 nil
    func removeLast() -> (key: Key, value: Value)? {
        guard let tailNode = tail else { return nil }

        let result = (key: tailNode.key, value: tailNode.value)
        remove(tailNode)

        return result
    }

    /// 移除指定节点（内部方法，不更新 count）
    private func remove(_ node: LRUNode<Key, Value>) {
        node.prev?.next = node.next
        node.next?.prev = node.prev

        if node === head {
            head = node.next
        }
        if node === tail {
            tail = node.prev
        }

        // 清理引用
        node.prev = nil
        node.next = nil
        count -= 1
    }
}

// MARK: - NtkRequestIdentifierManager

/// 请求标识符管理器
/// 负责为网络请求生成唯一的缓存键和去重标识符
/// 使用Swift Hasher确保高性能的哈希计算
@NtkActor
public class NtkRequestIdentifierManager {

    /// 内存缓存：请求特征 → 缓存键
    /// 避免重复计算相同请求的哈希
    private var requestCache: [RequestCacheKey: String] = [:]

    /// LRU 链表节点索引：请求特征 → 链表节点
    private var lruNodeIndex: [RequestCacheKey: LRUNode<RequestCacheKey, String>] = [:]

    /// LRU 双向链表：按访问顺序管理缓存键
    private let lruList = LRUList<RequestCacheKey, String>()

    /// 缓存最大容量
    private let maxCacheSize: Int

    private init() {
        // 基于设备物理内存分段计算，设置合理上限
        let totalMemoryMB = ProcessInfo.processInfo.physicalMemory / 1024 / 1024

        switch totalMemoryMB {
        case 0..<2048:      // < 2GB
            self.maxCacheSize = 100
        case 2048..<4096:   // 2GB - 4GB
            self.maxCacheSize = 300
        case 4096..<6144:   // 4GB - 6GB
            self.maxCacheSize = 500
        case 6144..<8192:   // 6GB - 8GB
            self.maxCacheSize = 800
        default:             // >= 8GB
            self.maxCacheSize = 1000
        }
    }

    /// 单例实例
    /// 确保全局唯一的标识符管理器
    public static let shared = NtkRequestIdentifierManager()

    /// 获取缓存键
    /// 为网络请求生成用于缓存的唯一标识符，考虑缓存配置
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - cacheConfig: 缓存配置，用于参数过滤
    /// - Returns: 缓存键字符串
    public func getCacheKey(request: NtkMutableRequest, cacheConfig: NtkRequestConfiguration?) -> String {
        let requestKey = RequestCacheKey(request: request, cacheConfig: cacheConfig)

        // 查询缓存
        if let node = lruNodeIndex[requestKey] {
            // // 缓存命中：更新 LRU 链表，移到头部
            lruList.moveToFirst(node)
            return node.value
        }

        // 计算新值
        let hash = generateHashForCache(request: request, cacheConfig: cacheConfig)
        let cacheKey = "cache_\(hash)"

        // 更新缓存（LRU 策略）
        if lruList.count >= maxCacheSize {
            // 删除最老的条目（链表尾部）
            if let removed = lruList.removeLast() {
                requestCache.removeValue(forKey: removed.key)
                lruNodeIndex.removeValue(forKey: removed.key)
            }
        }

        // 添加到缓存
        requestCache[requestKey] = cacheKey
        let newNode = lruList.addFirst(key: requestKey, value: cacheKey)
        lruNodeIndex[requestKey] = newNode

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
