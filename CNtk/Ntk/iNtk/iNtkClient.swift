//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

protocol iNtkClient {
    associatedtype Keys: NtkResponseMapKeys
    
    var request: iNtkRequest? { get }
    
    func addRequest(_ req: iNtkRequest)
    
    func execute<ResponseData>() async throws -> NtkResponse<ResponseData>
    
    func cancel()
    
    func loadCache<ResponseData>(_ storage: iNtkCacheStorage) async throws -> NtkResponse<ResponseData>?
    
    func hasCacheData(_ storage: iNtkCacheStorage) -> Bool
}

extension iNtkClient {
    
    func loadCache<ResponseData: Decodable>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        assert(request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: request!, storage: storage, cacheConfig: nil)
        let response: NtkResponse<ResponseData>? = try await cacheUtil.loadData()
        return response
    }
    
    func loadCache<ResponseData>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        fatalError("Swift都应该使用Codable进行模型解析")
    }
    
    func hasCacheData(_ storage: any iNtkCacheStorage) -> Bool {
        assert(request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: request!, storage: storage, cacheConfig: nil)
        return cacheUtil.hasData()
    }
}
