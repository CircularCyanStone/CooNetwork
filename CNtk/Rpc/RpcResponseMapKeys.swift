//
//  RpcResponseMapKeys.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation
struct RpcResponseMapKeys : NtkResponseMapKeys {
    static var code: String {
        "retCode"
    }
    
    static var data: String {
        "data"
    }
    
    static var msg: String {
        "retMsg"
    }
    
    
}
