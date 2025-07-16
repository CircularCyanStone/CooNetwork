//
//  NtkRequestContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

struct NtkRequestContext: Sendable {
    
    let validation: iNtkResponseValidation
    
    let client: any iNtkClient
    
    var extraData: [String: Sendable] = [:]
    
    init(validation: iNtkResponseValidation, client: any iNtkClient) {
        self.validation = validation
        self.client = client
    }
}
