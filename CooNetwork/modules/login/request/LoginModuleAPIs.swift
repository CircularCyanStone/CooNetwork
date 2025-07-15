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
        }
    }
    
    func OCResponseDataParse(_ retData: Any) throws -> Any {
        switch self {
        case .getTime:
            if let responseObj = retData as? [String: Sendable], let sysTime = responseObj["sysTime"] as? Int {
                return sysTime
            }else {
                return retData
            }
        }
    }
}
