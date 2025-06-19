//
//  NtkRequestContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

class NtkRequestContext {
    let validation: iNtkResponseValidation
    
    var extraData: [String: Any] = [:]
    
    init(validation: iNtkResponseValidation) {
        self.validation = validation
    }
}
