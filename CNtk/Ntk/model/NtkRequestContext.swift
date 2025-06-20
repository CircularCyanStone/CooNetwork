//
//  NtkRequestContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

class NtkRequestContext {
    let validation: iNtkResponseValidation
    
    let client: iNtkClient
    
    var extraData: [String: Any] = [:]
    
    init(validation: iNtkResponseValidation, client: iNtkClient) {
        self.validation = validation
        self.client = client
    }
}
