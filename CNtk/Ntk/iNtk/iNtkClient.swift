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
protocol iNtkClient: Sendable {
    /// 响应数据映射键的关联类型
    associatedtype Keys: NtkResponseMapKeys
    
    /// 请求包装器，用于传递请求和额外数据
    var requestWrapper: NtkRequestWrapper { get set }
    
    /// 缓存存储器
    /// - Returns: 用于缓存网络响应的存储实现
    var storage: iNtkCacheStorage { get }
    
    /// 执行网络请求
    /// - Returns: 原始的网络响应数据
    /// - Throws: 网络请求过程中的错误
    func execute() async throws -> Sendable
    
    /// 处理响应数据
    /// - Parameter response: 原始响应数据
    /// - Returns: 解析后的NtkResponse对象
    /// - Throws: 数据解析过程中的错误
    func handleResponse<ResponseData>(_ response: Sendable) async throws  -> NtkResponse<ResponseData>
    
    /// 取消当前请求
    func cancel()
    
    /// 加载缓存数据
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    func loadCache<ResponseData>() async throws -> NtkResponse<ResponseData>?
    
    /// 检查是否有缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    func hasCacheData() -> Bool
}

extension iNtkClient {
    
    /// 默认的缓存加载实现
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    func loadCache<ResponseData>() async throws -> NtkResponse<ResponseData>? {
        assert(requestWrapper.request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: requestWrapper.request!, storage: storage)
        let response = try await cacheUtil.loadData()
        guard let response else {
            return nil
        }
        let ntkResponse: NtkResponse<ResponseData> = try await handleResponse(response)
        return ntkResponse
    }
    
    /// 默认的缓存检查实现
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    func hasCacheData() -> Bool {
        assert(requestWrapper.request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: requestWrapper.request!, storage: storage)
        return cacheUtil.hasData()
    }
    
    /// 默认的取消实现
    /// 大多数客户端不支持直接取消，应使用Task.cancel()
    func cancel() {
        fatalError("\(self) not support, please use task.cancel()")
    }
}
