//
//  NtkObjcResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/4.
//

import Foundation

class NtkObjcResponse<ResponseData>: NSObject, iNtkResponse {
    
    let code: NtkReturnCode
    
    let data: ResponseData
    
    let msg: String?
    
    let response: Any
    
    let request: any iNtkRequest
    
    init(code: NtkReturnCode, data: ResponseData, msg: String?, response: Any, request: any iNtkRequest) {
        self.code = code
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
    }
}
