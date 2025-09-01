//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络客户端协议
/// 定义了网络请求执行的核心接口，支持不同的网络实现（如RPC、HTTP等）
@NtkActor
public protocol iNtkClient: Sendable {
    /// 响应数据映射键的关联类型
    associatedtype Keys: iNtkResponseMapKeys
    
    /// 缓存存储器
    /// - Returns: 用于缓存网络响应的存储实现
    var storage: iNtkCacheStorage { get set }
    
    /// 执行网络请求
    /// - Returns: 原始的网络响应数据
    /// - Throws: 网络请求过程中的错误
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse
    
    /// 取消当前请求
    func cancel()
    
    /// 加载缓存数据
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    func loadCache(_ request: NtkMutableRequest) async throws -> NtkClientResponse?
    
    func saveCache(_ request: NtkMutableRequest, response: Sendable) async -> Bool
    
    /// 检查是否有缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    func hasCacheData(_ request: NtkMutableRequest) async -> Bool
}

public extension iNtkClient {
    
    /// 默认的缓存加载实现
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    public func loadCache(_ request: NtkMutableRequest) async throws -> NtkClientResponse? {
        let cacheUtil = NtkNetworkCache(request: request, storage: storage)
        let response = try await cacheUtil.loadData()
        guard let response else {
            return nil
        }
        return NtkClientResponse(data: response, msg: nil, response: response, request: request, isCache: true)
    }
    
    /// 缓存响应结果到本地
    /// - Parameter response: 后端的响应
    /// - Returns: true成功 false失败
    public func saveCache(_ request: NtkMutableRequest, response: Sendable) async -> Bool {
        let cacheUtil = NtkNetworkCache(request: request, storage: storage)
        return await cacheUtil.save(data: response)
    }
    
    /// 默认的缓存检查实现
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    public func hasCacheData(_ request: NtkMutableRequest) async -> Bool {
        let cacheUtil = NtkNetworkCache(request: request, storage: storage)
        return cacheUtil.hasData()
    }
    
    /// 默认的取消实现
    /// 大多数客户端不支持直接取消，应使用Task.cancel()
    public func cancel() {
        fatalError("\(self) not support, please use task.cancel()")
    }
}
