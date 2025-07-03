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
    
    
    required init(_ client: iNtkClient) {
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
    
    func sendRequest<ResponseData: Codable>() async throws -> NtkResponse<ResponseData> {
        return try await operation.run()
    }
    
    //    func sendRequest<ResponseData: Codable>(_ completion: @escaping (_ result: ResponseData) -> Void, faliure: ((_ error: NtkError) -> Void)?) {
    //        assert(self.operation.validation != nil, "You should call the func validation() method first")
    //
    //        operation.run { response in
    //            completion(response)
    //        } failure: { error in
    //            faliure?(error)
    //        }
    //    }
    
    
    func loadCache<ResponseData: Codable>(_ storage: iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        return try await operation.loadCache(storage)
    }
    
    func hasCacheData(_ storage: iNtkCacheStorage) -> Bool {
        return operation.client.hasCacheData(storage)
    }
}
