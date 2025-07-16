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
    
    var storage: iNtkCacheStorage { get }
    
    func execute() async throws -> Sendable
    
    func handleResponse<ResponseData>(_ response: Sendable) async throws  -> NtkResponse<ResponseData>
    
    func cancel()
    
    func loadCache<ResponseData>() async throws -> NtkResponse<ResponseData>?
    
    func hasCacheData() -> Bool
}

extension iNtkClient {
    
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
    
    func hasCacheData() -> Bool {
        assert(requestWrapper.request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: requestWrapper.request!, storage: storage)
        return cacheUtil.hasData()
    }
    
    func cancel() {
        fatalError("\(self) not support, please use task.cancel()")
    }
}
