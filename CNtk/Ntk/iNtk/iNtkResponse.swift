//
//  iNtkResponse.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

protocol iNtkResponse {
    
    associatedtype ResponseData: Codable
    
    var code: NtkReturnCode { get }
    
    var data: ResponseData { get }
    
    var msg: String? { get }
    
    var response: Any { get }
    
    var request: iNtkRequest { get }
}
