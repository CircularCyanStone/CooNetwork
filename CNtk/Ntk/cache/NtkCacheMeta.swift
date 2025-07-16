//
//  NtkCacheMeta.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

/// 缓存元数据结构
/// 包含缓存数据的完整元信息，用于缓存的版本控制、过期管理和数据存储
struct NtkCacheMeta: Sendable {
    
    /// 缓存数据版本号
    /// 用于标识缓存数据对应的应用版本，便于版本升级时的缓存清理
    let appVersion: String
    
    /// 缓存创建时间
    /// 记录缓存数据的创建时间戳（毫秒），用于缓存统计和调试
    let creationDate: TimeInterval
    
    /// 缓存过期时间
    /// 缓存数据的过期时间戳（毫秒），超过此时间的缓存将被视为无效
    let expirationDate: TimeInterval
    
    /// 实际缓存数据
    /// 存储的网络响应数据，必须遵循Sendable协议以确保线程安全
    let data: Sendable
    
    /// 初始化缓存元数据
    /// - Parameters:
    ///   - appVersion: 应用版本号
    ///   - creationDate: 创建时间戳（毫秒）
    ///   - expirationDate: 过期时间戳（毫秒）
    ///   - data: 要缓存的数据
    init(appVersion: String, creationDate: TimeInterval, expirationDate: TimeInterval, data: Sendable) {
        self.appVersion = appVersion
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.data = data
    }
}
