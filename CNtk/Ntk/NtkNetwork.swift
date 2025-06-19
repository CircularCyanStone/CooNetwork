//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit


@objcMembers
class NtkNetwork<Keys: NtkResponseMapKeys>: NSObject {
    
    private let client: iNtkClient
    
    private let operation: NtkOperation
    
    required init(_ client: iNtkClient) {
        self.client = client
        operation = NtkOperation(client)
        super.init()
    }
    
    func with(_ request: iNtkRequest) -> Self {
        client.addRequest(request)
        return self
    }

    func validation(_ validation: iNtkResponseValidation) -> Self {
        self.operation.validation = validation
        return self
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
    
    func sendRequest<ResponseData: Codable>() async throws -> NtkResponse<ResponseData> {
        return try await operation.run()
    }
    
}
