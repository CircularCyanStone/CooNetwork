//
//  TFNCacheManager.swift
//  TAIChat
//
//  Created by AI Assistant on 2025/7/27.
//

import Foundation
import CryptoKit

// 导入相关协议和类型
// 注意：这些类型应该在同一个模块中，如果仍有错误，可能需要检查项目配置

/// TFN网络缓存管理器
/// 封装缓存key生成、数据存储、读取和检查功能的工具类
@TFNActor
final class TFNCacheManager {
    
    private var storage: any iTFNCacheStorage
    
    /// 初始化缓存管理器
    /// - Parameter storage: 缓存存储实现
    init(storage: any iTFNCacheStorage) {
        self.storage = storage
    }
    
    /// 根据请求生成缓存key
    /// 使用MD5哈希算法生成高性能且固定长度的缓存key
    /// 性能优化原因：
    /// 1. MD5比SHA256快约30-50%，性能优秀
    /// 2. 输出长度32字符，存储效率良好
    /// 3. 碰撞安全：结合URL、参数、headers等多维度信息，碰撞概率极低
    /// 4. 缓存场景优化：专为高频缓存key生成设计，性能与安全性平衡
    /// - Parameter request: 网络请求对象
    /// - Returns: 生成的MD5哈希缓存key字符串（32字符）
    func generateCacheKey(for request: TFNMutableRequest) -> String {
        let originalRequest = request
        let baseURL = originalRequest.baseURL
        let path = originalRequest.path
        let method = originalRequest.method.rawValue
        
        // 构建缓存key组件数组
        var keyComponents = ["\(baseURL)\(path)", "method_\(method)"]
        
        // 获取参数，如果有缓存策略则使用filterParameter过滤不稳定字段
        var finalParameters = originalRequest.parameters
        if let cachePolicy = originalRequest.cachePolicy {
            finalParameters = cachePolicy.filterParameter(originalRequest.parameters)
        }
        
        // 添加过滤后的参数到key组件中
        if let parameters = finalParameters {
            let sortedParams = parameters.keys.sorted().compactMap { key in
                "\(key)=\(parameters[key] ?? "nil")"
            }.joined(separator: "&")
            keyComponents.append("params_\(sortedParams)")
        }
        
        // 添加headers到key组件中（如果需要）
        if let headers = originalRequest.headers, !headers.isEmpty {
            let sortedHeaders = headers.keys.sorted().compactMap { key in
                "\(key)=\(headers[key] ?? "nil")"
            }.joined(separator: "&")
            keyComponents.append("headers_\(sortedHeaders)")
        }
        
        // 使用HashHelper生成MD5哈希key（32字符）
        // MD5在缓存场景下具有以下优势：
        // 1. 高性能：比SHA256快约30-50%
        // 2. 适中长度：32字符输出，存储效率良好
        // 3. 碰撞安全：结合URL、参数、headers等多维度信息，碰撞概率极低
        // 4. 适用性：专为缓存场景优化，性能与安全性平衡
        return HashHelper.generateFastCacheKeyHash(from: keyComponents)
    }
    
    /// 存储数据到缓存
    /// - Parameters:
    ///   - data: 要缓存的数据
    ///   - request: 网络请求对象
    /// - Returns: 存储操作是否成功
    @discardableResult
    func storeData<T: Sendable>(_ data: T, for request: TFNMutableRequest) async -> Bool {
        // 先添加请求到存储管理
        storage.addRequest(request)
        
        let key = generateCacheKey(for: request)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // 创建缓存元数据
        let metaData = TFNCacheMeta(
            appVersion: appVersion,
            creationDate: Date().timeIntervalSince1970,
            expirationDate: Date().timeIntervalSince1970 + (request.originalRequest.cachePolicy?.duration ?? 300),
            data: data
        )
        
        return await storage.setData(metaData: metaData, key: key)
    }
    
    /// 从缓存读取数据
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - type: 数据类型
    /// - Returns: 缓存的数据，如果缓存不存在或已过期则返回nil
    func loadData<T: Sendable>(for request: TFNMutableRequest) async -> T? {
        let key = generateCacheKey(for: request)
        guard let metaData = await storage.getData(key: key) else {
            return nil
        }
        
        // 检查是否过期
        let currentTime = Date().timeIntervalSince1970
        if currentTime > metaData.expirationDate {
            return nil
        }
        return metaData.data as? T
    }
    
    /// 检查缓存是否存在且有效
    /// - Parameter request: 网络请求对象
    /// - Returns: 如果存在有效缓存返回true，否则返回false
    func hasValidCache(for request: TFNMutableRequest) async -> Bool {
        let key = generateCacheKey(for: request)
        return await storage.hasData(key: key)
    }
}

// MARK: - 便捷方法
extension TFNCacheManager {
    
    /// 存储字符串数据
    @discardableResult
    func storeString(_ string: String, for request: TFNMutableRequest) async -> Bool {
        return await storeData(string, for: request)
    }
    
    /// 读取字符串数据
    func loadString(for request: TFNMutableRequest) async -> String? {
        return await loadData(for: request)
    }
    
    /// 存储字典数据
    @discardableResult
    func storeDictionary(_ dictionary: [String: Sendable], for request: TFNMutableRequest) async -> Bool {
        return await storeData(dictionary, for: request)
    }
    
    /// 读取字典数据
    func loadDictionary(for request: TFNMutableRequest) async -> [String: Sendable]? {
        return await loadData(for: request)
    }
}
