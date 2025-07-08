//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

protocol iNtkClient {
    
    var request: iNtkRequest? { get }
    
    var isFinished: Bool { get }
    
    var isCancelled: Bool { get }
    
    func addRequest(_ req: iNtkRequest)
    
    func execute<ResponseData>() async throws -> NtkResponse<ResponseData>
    
    func cancel()
    
    func loadCache<ResponseData>(_ storage: iNtkCacheStorage) async throws -> NtkResponse<ResponseData>?
    
    func hasCacheData(_ storage: iNtkCacheStorage) -> Bool
    
}

extension iNtkClient {
    
    func loadCache<ResponseData>(_ storage: iNtkCacheStorage) async -> NtkResponse<ResponseData>? {
        fatalError("\(self) no implement iNtkClient loadCache")
    }
}
