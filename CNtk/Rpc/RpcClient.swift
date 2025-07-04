//
//  RpcClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/4.
//

import Foundation

//class RpcClient<Keys: NtkResponseMapKeys>: iNtkClient {
//    var request: (any iNtkRequest)?
//    
//    var isFinished: Bool = false
//    
//    var isCancelled: Bool = false
//    
//    func addRequest(_ req: any iNtkRequest) {
//        self.request = req
//    }
//    
//    func execute<ResponseData: Codable>() async throws -> NtkResponse<ResponseData> {
//        guard let request else {
//            fatalError("request can not be nil")
//        }
//        let method = DTRpcMethod()
//        let parameters = request.parameters ?? [:]
//        let headers = request.headers ?? [:]
//        
//        let response = try await withUnsafeThrowingContinuation { continuation in
//            DTRpcAsyncCaller.callSwiftAsyncBlock {
//                let responseObject = DTRpcClient.default().execute(method, params: [parameters], requestHeaderField: headers) { headerFile in
//                    
//                }
//                if responseObject != nil {
//                    continuation.resume(returning: responseObject!)
//                }else {
//                    continuation.resume(throwing: NtkError.Rpc.responseEmpty)
//                }
//            } completion: { error in
//                if let error {
//                    continuation.resume(throwing: error)
//                }else {
//                    continuation.resume(throwing: NtkError.Rpc.unknown(msg: "request error, but error info is nil"))
//                }
//            }
//        }
//        
//        
//        
////        let responseData = try okResponse.map(NtkResponseDecoder<ResponseData, Keys>.self)
////        if let returnData = responseData.data {
////            let fixResponse = NtkResponse(code: responseData.code, data: returnData, msg: responseData.msg, response: okResponse, request: self.request!)
////            continuatuon.resume(returning: fixResponse)
////        }else if ResponseData.self is NtkNever.Type {
////            // 用户期待的数据类型就是Never，啥都没有
////            let fixResponse = NtkResponse(code: responseData.code, data: NtkNever() as! ResponseData, msg: responseData.msg, response: response, request: self.request!)
////            continuatuon.resume(returning: fixResponse)
////        }else {
////            // 后端code验证成功，但是没有得到匹配的数据类型
////            throw NtkError.retDataError
////        }
//
//        
//        
////        let response = NtkResponse(code: NtkReturnCode, data: <#T##Decodable & Encodable#>, msg: <#T##String?#>, response: <#T##Any#>, request: <#T##any iNtkRequest#>)
//        
//    }
//    
//    func cancel() {
//        
//    }
//    
//    func hasCacheData(_ storage: any iNtkCacheStorage) -> Bool {
//        true
//    }
//}
