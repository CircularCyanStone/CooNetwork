//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit


class NtkNetwork<ResponseData: Sendable> {
    
    private let operation: NtkOperation
    
    private var currentRequestTask: Task<NtkResponse<ResponseData>, any Error>?
    
    var isCancelled: Bool {
        currentRequestTask?.isCancelled ?? Task.isCancelled
    }
    
    required init(_ client: any iNtkClient) {
        operation = NtkOperation(client)
    }
    
    func cancel() {
        currentRequestTask?.cancel()
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
    
    func sendRequest() async throws -> NtkResponse<ResponseData> {
        let task: Task<NtkResponse<ResponseData>, any Error> = Task {
            try await operation.run()
        }
        self.currentRequestTask = task
        return try await task.value
    }
    
    
    func loadCache(_ storage: iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        return try await operation.loadCache(storage)
    }
    
    /// 判断是否有缓存
    /// - Parameter storage: 存储工具
    func hasCacheData(_ storage: iNtkCacheStorage) -> Bool {
        return operation.client.hasCacheData(storage)
    }
}
