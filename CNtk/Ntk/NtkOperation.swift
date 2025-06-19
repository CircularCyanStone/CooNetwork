//
//  NtkOperation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

@objcMembers
class NtkOperation: NSObject {

    private var client: iNtkClient
    
    private var validation: iNtkResponseValidation
    
    required
    init(_ client: iNtkClient, validation: iNtkResponseValidation) {
        self.client = client
        self.validation = validation
        super.init()
    }
    
    
    func run<ResponseData: Codable>(_ completion: @escaping (_ response: ResponseData) -> Void, failure: @escaping (_ error: iNtkError) -> Void) {
        client.execute { response in
            self.responseHandle(response, completion: completion)
        } failure: { error in
            self.responseError(failure: failure)
        }
    }
    
    
    
    private func responseHandle<ResponseData: Codable>(_ response: NtkResponse<ResponseData>, completion: (_ response: ResponseData) -> Void) {
        
        
        
        
    }
    
    private func responseError(failure: (_ error: iNtkError) -> Void) {
        
    }
}
