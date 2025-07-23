//
//  RpcCacheStorage.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/15.
//

import Foundation

let RpcCacheBusinessKey = "rpc_cache"

struct RpcCacheStorage: iNtkCacheStorage {
    
    private var request: (any iRpcRequest)?
    
    mutating func addRequest(_ request: any iNtkRequest) {
        self.request = request as? iRpcRequest
    }
    
    func setData(metaData: NtkCacheMeta, key: String) async -> Bool {
        guard let request else {
            fatalError("request is nil or not iRpcRequest")
        }
        var result: Bool
        if request.checkLogin {
            result = APDataCenter.default().userPreferences().archiveObject(metaData, forKey: key, business: RpcCacheBusinessKey)
        }else {
            result = APDataCenter.default().commonPreferences().archiveObject(metaData, forKey: key, business: RpcCacheBusinessKey)
        }
        print("网络请求 \(request) 缓存 \(result ? "成功" : "失败")")
        return result
    }
    
    func getData(key: String) async -> NtkCacheMeta? {
        print("startRpc 读取缓存")
        guard let request else {
            fatalError("request is nil or not iRpcRequest")
        }
        if request.checkLogin {
            let result = APDataCenter.default().userPreferences().object(forKey: key, business: RpcCacheBusinessKey)
            return result as? NtkCacheMeta
        }else {
            let result = APDataCenter.default().commonPreferences().object(forKey: key, business: RpcCacheBusinessKey)
            return result as? NtkCacheMeta
        }
    }
    
    func hasData(key: String) -> Bool {
        guard let request else {
            fatalError("request is nil or not iRpcRequest")
        }
        if request.checkLogin {
            let result = APDataCenter.default().userPreferences().itemExists(forKey: key, business: RpcCacheBusinessKey)
            return result
        }else {
            let result = APDataCenter.default().commonPreferences().itemExists(forKey: key, business: RpcCacheBusinessKey)
            return result
        }
    }
    
    
}
