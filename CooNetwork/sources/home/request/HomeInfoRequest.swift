//
//  HomeInfoRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

@objcMembers
final class HomeInfoRequest: NSObject, iRpcRequest {
    var parameters: [String : any Sendable]? {
        [:]
    }
    
    
    let path: String = ""
    
    func OCResponseDataDecode(_ retData: Any) throws -> Any {
        retData
    }
}
