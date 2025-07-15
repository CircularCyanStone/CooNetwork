//
//  LoginModuleAPIs.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/14.
//

import Foundation

enum Login: iRpcRequest {
    
    case getTime
    
    var path: String {
        switch self {
        case .getTime:
            "com.emp.bosc.getCurrentSysTime"
        default:
            ""
        }
    }
}
