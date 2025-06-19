//
//  iNtkResponseValidation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

protocol iNtkResponseValidation {
    
    func isServiceSuccess<ResponseData: Codable>(_ response: NtkResponse<ResponseData>) -> Bool
    
}
