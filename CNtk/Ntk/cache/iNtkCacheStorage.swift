//
//  NtkCacheStorage.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

/// 网络缓存存储协议
/// 定义了缓存存储的核心接口，支持数据的存储、读取和检查功能
/// 实现类需要提供具体的缓存存储机制（如磁盘缓存、内存缓存等）
@NtkActor
protocol iNtkCacheStorage: Sendable {
    
    /// 添加请求到缓存管理
    /// 用于注册需要缓存的请求，可用于预处理或统计
    /// - Parameter request: 网络请求对象
    mutating func addRequest(_ request: iNtkRequest)
    
    /// 存储数据到缓存
    /// 将网络响应数据及其元信息保存到缓存存储中
    /// - Parameters:
    ///   - metaData: 包含数据和元信息的缓存元数据
    ///   - key: 唯一的缓存键，用于标识和检索缓存数据
    /// - Returns: 存储操作是否成功
    func setData(metaData: NtkCacheMeta, key: String) async -> Bool
    
    /// 从缓存获取数据
    /// 根据缓存键检索对应的缓存数据和元信息
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的元数据对象，如果缓存不存在则返回nil
    func getData(key: String) async -> NtkCacheMeta?
    
    /// 检查缓存是否存在
    /// 快速检查指定键的缓存数据是否存在，不读取实际数据
    /// - Parameter key: 缓存键
    /// - Returns: 如果缓存存在返回true，否则返回false
    func hasData(key: String) -> Bool
}
