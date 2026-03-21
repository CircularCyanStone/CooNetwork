//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

/// 网络客户端协议
/// 定义了网络请求执行的核心接口，支持不同的网络实现（如RPC、HTTP等）
public protocol iNtkClient: Sendable {

    /// 执行网络请求
    /// - Returns: 原始的网络响应数据
    /// - Throws: 网络请求过程中的错误
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse

    /// 取消当前请求
    func cancel()
}

public extension iNtkClient {
    /// 默认的取消实现
    /// 大多数客户端不支持直接取消，应使用Task.cancel()
    func cancel() {
        fatalError("\(self) not support, please use task.cancel()")
    }
}

// MARK: - 缓存能力协议

/// 可缓存的网络客户端协议
/// 将缓存能力从 iNtkClient 中分离，遵循接口隔离原则
/// 只有需要缓存功能的后端才需要实现此协议
public protocol iNtkCacheableClient: Sendable {
    /// 缓存存储器
    var storage: iNtkCacheStorage { get }

    /// 加载缓存数据
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    @NtkActor
    func loadCache(_ request: NtkMutableRequest) async throws -> NtkClientResponse?

    @NtkActor
    func saveCache(_ request: NtkMutableRequest, response: Sendable) async -> Bool

    /// 检查是否有缓存数据
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    @NtkActor
    func hasCacheData(_ request: NtkMutableRequest) async -> NtkResponse<Bool>
}

public extension iNtkCacheableClient {

    /// 默认的缓存加载实现
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    @NtkActor
    func loadCache(_ request: NtkMutableRequest) async throws -> NtkClientResponse? {
        let cacheUtil = NtkNetworkCache(storage: storage)
        let response = try await cacheUtil.loadData(for: request)
        guard let response else {
            return nil
        }
        return NtkClientResponse(data: response, msg: nil, response: response, request: request, isCache: true)
    }

    /// 缓存响应结果到本地
    /// - Parameter response: 后端的响应
    /// - Returns: true成功 false失败
    @NtkActor
    func saveCache(_ request: NtkMutableRequest, response: Sendable) async -> Bool {
        let cacheUtil = NtkNetworkCache(storage: storage)
        return await cacheUtil.save(data: response, for: request)
    }

    /// 默认的缓存检查实现
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    @NtkActor
    func hasCacheData(_ request: NtkMutableRequest) async -> NtkResponse<Bool> {
        let cacheUtil = NtkNetworkCache(storage: storage)
        let result = await cacheUtil.hasData(for: request)
        let response = NtkResponse(code: .init(200), data: result, msg: nil, response: result, request: request, isCache: true)
        return response
    }
}
