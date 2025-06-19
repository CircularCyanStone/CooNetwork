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
    
    func execute<ResponseData: Codable>(_ completion: @escaping (_ response: NtkResponse<ResponseData>) -> Void, failure: (_ error: iNtkError) -> Void)
    
//    func execute(_ completion: (_ result: Result<Bool, Error>) -> Void) throws
    
    func execute() async throws 
    
    func cancel()
}
