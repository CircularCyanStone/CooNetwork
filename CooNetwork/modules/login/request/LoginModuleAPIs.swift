//
//  LoginModuleAPIs.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/14.
//

import Foundation
import NtkNetwork

enum Login: iRpcRequest {
    
    // 获取服务器时间
    case getTime
    
    // 发短信
    case sendSMS(_ userId: String, tmpLogin: Bool)
    
    var path: String {
        switch self {
        case .getTime:
            "com.emp.bosc.getCurrentSysTime"
        case .sendSMS:
            "com.emp.bosc.sendShortMsg2"
        }
    }
    
    var parameters: [String : any Sendable]? {
        var params: [String : any Sendable] = [:]
        switch self {
        case let .sendSMS(userId, tmp):
            params["queryId"] = "E3ADS3LI3ABMZJE3ZIE"
            params["msgAuthType"] = "iamgate"
            if tmp {
                // 2023.06.07新增：非行员临时登录需要传登录类型
                params["loginType"] = "5"
                params["mobile"] = userId
            }else {
                params["empId"] = userId
            }
        default:
            break
        }
        return params
    }
    
    func customRetureDataDecode(_ retData: any Sendable) throws -> any Sendable {
        switch self {
        case .getTime:
            if let responseObj = retData as? [String: Sendable], let sysTime = responseObj["sysTime"] as? Int {
                return sysTime
            }else {
                return retData
            }
        default:
            return retData
        }
    }
    
    var requestConfiguration: (any iNtkRequestConfiguration)? {
        NtkDefaultRequestConfiguration(cacheTime: 3600*24*30)
    }
    
    var checkLogin: Bool {
        false
    }
}

extension Login: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        switch self {
        case .sendSMS:
            if let code = response.code.int, code == 100 {
                return true
            }
            if response.code.stringValue == "100" {
                return true
            }
            return false
        default:
            if let code = response.code.int, code == 0 {
                return true
            }
            if response.code.stringValue == "0" {
                return true
            }
            return false
        }
    }
}
