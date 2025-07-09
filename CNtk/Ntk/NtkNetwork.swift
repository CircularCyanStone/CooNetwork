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
    
    class func with(_ request: iNtkRequest, client: any iNtkClient) -> Self {
        let net = self.init(client)
        return net.with(request)
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
    
    func addInterceptor(_ i: iNtkInterceptor) {
        operation.addInterceptor(i)
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
    
    // 适配OC的闭包回调方式
    // 后续还要实现一个OC的中间层，可能不需要这里
    func sendnRequest(_ completion: @escaping (NtkResponse<ResponseData>) -> Void, failure: ((any Error) -> Void)?) {
        Task {
            do {
                let response: NtkResponse<ResponseData> = try await operation.run()
                completion(response)
            }catch {
                failure?(error)
            }
        }
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
