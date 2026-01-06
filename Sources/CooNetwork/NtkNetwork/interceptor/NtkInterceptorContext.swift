//
//  NtkInterceptorContext.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

@NtkActor
public final class NtkInterceptorContext: Sendable {
    
    public var mutableRequest: NtkMutableRequest
    
    public let validation: iNtkResponseValidation
    
    public let client: any iNtkClient
    
    public var extraData: [String: Sendable] = [:]
    
    init(mutableRequest: NtkMutableRequest, validation: iNtkResponseValidation, client: any iNtkClient) {
        self.mutableRequest = mutableRequest
        self.validation = validation
        self.client = client
    }
}
