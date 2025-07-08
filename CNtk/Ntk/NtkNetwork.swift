//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit


@objcMembers
class NtkNetwork: NSObject {
    
    private let operation: NtkOperation
    
    var isFinished: Bool {
        operation.client.isFinished
    }
    
    var isCancelled: Bool {
        operation.client.isCancelled
    }
    
    
    required init(_ client: any iNtkClient) {
        operation = NtkOperation(client)
        super.init()
    }
    
    func cancel() {
        operation.client.cancel()
    }
}

extension NtkNetwork {
    
    func with(_ request: iNtkRequest) -> Self {
        operation.client.addRequest(request)
        return self
    }

    func validation(_ validation: iNtkResponseValidation) -> Self {
        self.operation.validation = validation
        return self
    }
    
    func sendRequest<ResponseData>() async throws -> NtkResponse<ResponseData> {
        return try await operation.run()
    }
    
    
    func loadCache<ResponseData>(_ storage: iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        return try await operation.loadCache(storage)
    }
    
    /// 判断是否有缓存
    /// - Parameter storage: 存储工具
    func hasCacheData(_ storage: iNtkCacheStorage) -> Bool {
        return operation.client.hasCacheData(storage)
    }
}
