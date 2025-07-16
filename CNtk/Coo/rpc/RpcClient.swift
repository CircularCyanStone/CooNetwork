//
//  RpcClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/4.
//

import Foundation
import UIKit

@NtkActor
class RpcClient<Keys: NtkResponseMapKeys>: iNtkClient {
    
    var storage: any iNtkCacheStorage = RpcCacheStorage()
    
    var requestWrapper: NtkRequestWrapper = NtkRequestWrapper()
    
    private var request: iNtkRequest? {
        requestWrapper.request
    }
    
    private func sendRpcRequest() async throws -> Sendable {
        guard let request = requestWrapper.request as? iRpcRequest else {
            fatalError("request must be iRpcRequest")
        }
        let method = DTRpcMethod()
        method.operationType = request.path
        method.checkLogin = request.checkLogin
        method.timeoutInterval = request.timeout
        method.returnType = "@\"NSDictionary\""
        let parameters = request.parameters ?? [:]
        let headers = request.headers ?? [:]
        
        try Task.checkCancellation()
        let response: Sendable = try await withUnsafeThrowingContinuation { continuation in
            DTRpcAsyncCaller.callSwiftAsyncBlock {
                let responseObject = DTRpcClient.default().execute(method, params: [parameters], requestHeaderField: headers) { headerFile in
                    
                }
                if let responseObject {
                    if let responseDict = responseObject as? [String: any Sendable] {
                        continuation.resume(returning: responseDict)
                    }else if let responseArray = responseObject as? [any Sendable] {
                        continuation.resume(returning: responseArray)
                    }else {
                        continuation.resume(throwing: NtkError.Rpc.responseTypeError)
                    }
                }else {
                    continuation.resume(throwing: NtkError.Rpc.responseEmpty)
                }
            } completion: { error in
                if let error {
                    // 接口报错时会走这里
                    continuation.resume(throwing: error)
                }
            }
        }
        try Task.checkCancellation()
        return response
    }
}

extension RpcClient {
    func execute<ResponseData>() async throws -> NtkResponse<ResponseData> {
        if ResponseData.self is Decodable.Type {
            return try await handleDecodableRuntime()
        } else {
            return try await handleNSObject()
        }
    }
    
    private func handleDecodableRuntime<ResponseData>() async throws -> NtkResponse<ResponseData> {
        let response = try await sendRpcRequest()
        guard let sendableResponse = response as? [String: Sendable] else {
            fatalError("接口数据仅支持sendable类型的数据，请核对")
        }
        let code = sendableResponse[Keys.code]
        let msg = sendableResponse[Keys.msg] as? String
        let retCode = NtkReturnCode(code)
        if ResponseData.self is NtkNever.Type {
            // 用户期待的数据类型就是Never，啥都没有
            let fixResponse = NtkResponse(code: retCode, data: NtkNever() as! ResponseData, msg: msg, response: sendableResponse, request: self.request!)
            return fixResponse
        }
        
        guard let data = sendableResponse[Keys.data] else {
            throw NtkError.serviceDataEmpty
        }
        
        do {
            guard JSONSerialization.isValidJSONObject(data) else {
                // 后端code验证成功，但是没有得到匹配的数据类型
                throw NtkError.jsonInvalid(request!, sendableResponse)
            }
            let responseData = try JSONSerialization.data(withJSONObject: data)
            
            // 使用运行时类型转换
            if let decodableType = ResponseData.self as? Decodable.Type {
                let decoded = try JSONDecoder().decode(decodableType, from: responseData)
                let fixResponse = NtkResponse(code: retCode, data: decoded as! ResponseData, msg: msg, response: sendableResponse, request: self.request!)
                return fixResponse
            } else {
                throw NtkError.serviceDataTypeInvalid
            }
        } catch let error as DecodingError {
            // decoder字段解析报错，避免崩溃
            throw NtkError.decodeInvalid(error, request!, sendableResponse)
        } catch {
            // 后端code验证成功，但是没有得到匹配的数据类型
            throw NtkError.serviceDataTypeInvalid
        }
    } 
    
    private func handleNSObject<ResponseData>() async throws -> NtkResponse<ResponseData> {
        let response = try await sendRpcRequest()
        if let resposneObject = response as? [String: Sendable] {
            let code = resposneObject[Keys.code]
            guard let data = resposneObject[Keys.data] else {
                throw NtkError.serviceDataEmpty
            }
            let msg = resposneObject[Keys.msg] as? String
            let retCode = NtkReturnCode(code)
            if request is iRpcRequest {
                /**
                 因为要适配OC，使用手动模型解析。
                 当遇到数组类型的数据时，ResponseData代表的是数组。
                 但是在OC里需要使用ResponseData数组里面的元素类型才能进行模型解析。
                 所以不适用统一做自动解析。
                 */
                let rpcRequest = request as! iRpcRequest
                if ResponseData.self is NtkNever.Type {
                    // 用户不关心retData
                    let response = NtkResponse(code: retCode, data: NtkNever(), msg: msg, response: resposneObject, request: request!)
                    return response as! NtkResponse<ResponseData>
                }
                guard let retData = try rpcRequest.OCResponseDataParse(data) as? ResponseData else {
                    throw NtkError.serviceDataTypeInvalid
                }
                let response = NtkResponse(code: retCode, data: retData, msg: msg, response: resposneObject, request: request!)
                return response
            }else {
                fatalError("RpcClient only support RpcRequest \(String(describing: request))")
            }
        }else {
            throw NtkError.Rpc.responseTypeError
        }

    }
    
}
