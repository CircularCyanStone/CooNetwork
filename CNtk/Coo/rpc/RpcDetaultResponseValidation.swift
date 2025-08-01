//
//  RpcDetaultInva.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/14.
//

import Foundation
import NtkNetwork

struct RpcDetaultResponseValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        if let code = response.code.int, code == 0 {
            return true
        }
        if response.code.stringValue == "0" {
            return true
        }
        return false
    }
}
