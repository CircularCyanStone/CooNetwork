//
//  RpcClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/4.
//

import Foundation

/// RPC客户端实现
/// 负责执行RPC网络请求，支持泛型响应键映射和缓存功能
/// 集成了DTRpc框架进行底层网络通信
class RpcClient<Keys: NtkResponseMapKeys>: iNtkClient {
    
    /// 缓存存储实现
    var storage: any iNtkCacheStorage = RpcCacheStorage()
    
    /// 请求包装器
    var requestWrapper: NtkRequestWrapper = NtkRequestWrapper()
    
    /// 当前请求对象
    private var request: iNtkRequest? {
        requestWrapper.request
    }
    
    /// 发送RPC请求
    /// 使用DTRpc框架执行底层网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
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
    
    /// 执行网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    func execute() async throws -> any Sendable {
        try await sendRpcRequest()
    }
    
    /// 处理响应数据
    /// 根据响应数据类型选择不同的处理策略
    /// - Parameter response: 服务端响应数据
    /// - Returns: 类型化的网络响应对象
    /// - Throws: 数据处理过程中的错误
    func handleResponse<ResponseData>(_ response: any Sendable) async throws -> NtkResponse<ResponseData> where ResponseData : Sendable {
        return try await handleDecodableRuntime(response)
    }
    
    /// 处理Decodable类型的响应数据
    /// 根据enableCustomResponseDataDecode属性选择解码策略
    /// - Parameter response: 服务端响应数据
    /// - Returns: 类型化的网络响应对象
    /// - Throws: JSON解析或类型转换错误
    private func handleDecodableRuntime<ResponseData>(_ response: any Sendable) async throws -> NtkResponse<ResponseData> {
        guard let rpcRequest = request as? iRpcRequest else {
            fatalError("request must be iRpcRequest type")
        }
        let response = try await sendRpcRequest()
        guard let sendableResponse = response as? [String: Sendable] else {
            throw NtkError.Rpc.responseTypeError
        }
        let code = sendableResponse[Keys.code]
        let msg = sendableResponse[Keys.msg] as? String
        let retCode = NtkReturnCode(code)
        
        if ResponseData.self is NtkNever.Type {
            // 用户期待的数据类型就是Never，不需要数据
            let fixResponse = NtkResponse(code: retCode, data: NtkNever() as! ResponseData, msg: msg, response: response, request: rpcRequest)
            return fixResponse
        }
        
        guard let data = sendableResponse[Keys.data] else {
            throw NtkError.serviceDataEmpty
        }
        
        do {
            // 检查是否启用自定义响应数据解码
            var enableCustomResponseDataDecode: Bool = rpcRequest.enableCustomRetureDataDecode
            if !enableCustomResponseDataDecode {
                if ResponseData.self is String.Type || ResponseData.self is Bool.Type || ResponseData.self is Int.Type || ResponseData.self is [String: Sendable].Type {
                    enableCustomResponseDataDecode = true
                }
            }
            
            if enableCustomResponseDataDecode {
                // 使用自定义解码器
                if let retData = try rpcRequest.customRetureDataDecode(data) as? ResponseData {
                    let response = NtkResponse(code: retCode, data: retData, msg: msg, response: response, request: request!)
                    return response
                } else {
                    throw NtkError.serviceDataTypeInvalid
                }
            }
            // 使用默认的JSONDecoder自动解码
            guard JSONSerialization.isValidJSONObject(data) else {
                // 后端code验证成功，但是没有得到匹配的数据类型
                throw NtkError.jsonInvalid(request!, sendableResponse)
            }
            let responseData = try JSONSerialization.data(withJSONObject: data)
            
            // 使用运行时类型转换
            if let decodableType = ResponseData.self as? Decodable.Type {
                let decoded = try JSONDecoder().decode(decodableType, from: responseData)
                let fixResponse = NtkResponse(code: retCode, data: decoded as! ResponseData, msg: msg, response: response, request: self.request!)
                return fixResponse
            } else {
                throw NtkError.serviceDataTypeInvalid
            }
        } catch let error as DecodingError {
            // decoder字段解析报错，避免崩溃
            throw NtkError.decodeInvalid(error, request!, sendableResponse)
        } catch {
            // 重新抛出其他错误
            throw error
        }
    }
    
}
