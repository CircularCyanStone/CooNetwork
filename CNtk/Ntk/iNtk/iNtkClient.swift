//
//  iNtkClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

protocol iNtkClient {
    
    var request: iNtkRequest? { get }
    
    var isFinished: Bool { get }
    
    var isCancelled: Bool { get }
    
    func addRequest(_ req: iNtkRequest)
    
    func execute<ResponseData: Codable>() async throws -> NtkResponse<ResponseData>
    
    func cancel()
}
