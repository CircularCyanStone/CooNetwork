//
//  RpcResponseMapKeys.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation
import NtkNetwork

struct RpcResponseMapKeys : iNtkResponseMapKeys {
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
