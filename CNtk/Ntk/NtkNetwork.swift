//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit


@objcMembers
class NtkNetwork<Keys: NtkResponseMapKeys>: NSObject {
    
    let client: iNtkClient
    
    private var validation: iNtkResponseValidation?
    
    required init(_ client: iNtkClient) {
        self.client = client
        super.init()
    }
    
    func with(_ request: iNtkRequest) -> Self {
        client.addRequest(request)
        return self
    }

    func validation(_ validation: iNtkResponseValidation) -> Self {
        self.validation = validation
        return self
    }
    
    func sendRequest<ResponseData: Codable>(_ completion: @escaping (_ result: ResponseData) -> Void, faliure: ((_ error: iNtkError) -> Void)?) {
        assert(validation != nil, "You should call the func validation() method first")
        let operation = NtkOperation(client,validation: validation!)
        operation.run { response in
            completion(response)
        } failure: { error in
            faliure?(error)
        }
    }
    
}
