//
//  NtkClientResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/29.
//

import Foundation

public struct NtkClientResponse: iNtkResponse {
    
    public typealias ResponseData = Sendable
    
    public var code: NtkReturnCode {
        NtkReturnCode(-1)
    }
    public let data: any ResponseData
    
    public let msg: String?
    
    public let response: any Sendable
    
    public let request: any iNtkRequest
    
    public let isCache: Bool
    
    public init(data: any ResponseData, msg: String?, response: any Sendable, request: any iNtkRequest, isCache: Bool) {
        self.data = data
        self.msg = msg
        self.response = response
        self.request = request
        self.isCache = isCache
    }
}
