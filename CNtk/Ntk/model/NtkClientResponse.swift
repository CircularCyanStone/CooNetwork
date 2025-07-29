//
//  NtkClientResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/29.
//

import Foundation

struct NtkClientResponse: iNtkResponse {
    
    typealias ResponseData = Sendable
    var code: NtkReturnCode {
        NtkReturnCode(-1)
    }
    let data: any ResponseData
    
    let msg: String?
    
    let response: any Sendable
    
    let request: any iNtkRequest
    
    let isCache: Bool
    
}
