//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

@NtkActor
protocol iNtkClient: Sendable {
    associatedtype Keys: NtkResponseMapKeys
    
    var requestWrapper: NtkRequestWrapper { get set }
    
    func execute<ResponseData>() async throws -> NtkResponse<ResponseData>
    
    func cancel()
    
    func loadCache<ResponseData>(_ storage: iNtkCacheStorage) async throws -> NtkResponse<ResponseData>?
    
    func hasCacheData(_ storage: iNtkCacheStorage) -> Bool
}

extension iNtkClient {
    
    func loadCache<ResponseData: Decodable>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        assert(requestWrapper.request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: requestWrapper.request!, storage: storage, cacheConfig: nil)
        let response: NtkResponse<ResponseData>? = try await cacheUtil.loadData()
        return response
    }
    
    func loadCache<ResponseData>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        fatalError("Swift都应该使用Codable进行模型解析")
    }
    
    func hasCacheData(_ storage: any iNtkCacheStorage) -> Bool {
        assert(requestWrapper.request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: requestWrapper.request!, storage: storage, cacheConfig: nil)
        return cacheUtil.hasData()
    }
    
    func cancel() {
        fatalError("\(self) not support, please use task.cancel()")
    }
}
