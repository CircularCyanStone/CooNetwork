//
//  HomeInfoRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

final class HomeInfoRequest: RpcRequest {
    var parameters: [String : any Sendable]? {
        [:]
    }
    
    
    let path: String = ""
    
    func OCResponseDataParse(_ retData: Any) throws -> Any {
        retData
    }
    
    
}
