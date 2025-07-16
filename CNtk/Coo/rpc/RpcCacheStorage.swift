//
//  RpcCacheStorage.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/15.
//

import Foundation

struct RpcCacheStorage: iNtkCacheStorage {
    
    func addRequest(_ request: any iNtkRequest) {
        
    }
    
    func setData(metaData: NtkCacheMeta, key: String) async -> Bool {
        true
    }
    
    func getData(key: String) async -> NtkCacheMeta? {
        nil
    }
    
    func hasData(key: String) -> Bool {
        true
    }
    
    
}
