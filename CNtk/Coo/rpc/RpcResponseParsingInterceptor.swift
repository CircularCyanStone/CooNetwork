//
//  RpcResponseParsingInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/29.
//

import Foundation
import NtkNetwork

struct RpcResponseParsingInterceptor<ResponseData: Sendable, Keys: iNtkResponseMapKeys>: iNtkInterceptor {
    func intercept(context: NtkInterceptorContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        guard let clientResponse = response as? NtkClientResponse else {
            if let ntkResponse = response as? NtkResponse<ResponseData> {
                return ntkResponse
            }
            fatalError("RpcClient func execute() result type error ")
        }
        guard let rpcRequest = context.mutableRequest.originalRequest as? iRpcRequest else {
            fatalError("request must be iRpcRequest type")
        }
        return try await handleDecodableRuntime(rpcRequest, response: clientResponse)
    }
    
    /// 处理Decodable类型的响应数据
    /// 根据enableCustomResponseDataDecode属性选择解码策略
    /// - Parameter response: 服务端响应数据
    /// - Returns: 类型化的网络响应对象
    /// - Throws: JSON解析或类型转换错误
    private func handleDecodableRuntime(_ rpcRequest: iRpcRequest, response: NtkClientResponse) async throws -> NtkResponse<ResponseData> {
        
        guard let sendableResponse = response.response as? [String: Sendable] else {
            throw NtkError.Rpc.responseTypeError
        }
        let code = sendableResponse[Keys.code]
        let msg = sendableResponse[Keys.msg] as? String
        let retCode = NtkReturnCode(code)
        
        if ResponseData.self is NtkNever.Type {
            // 用户期待的数据类型就是Never，不需要数据
            let fixResponse = NtkResponse(code: retCode, data: NtkNever() as! ResponseData, msg: msg, response: response, request: rpcRequest, isCache: response.isCache)
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
                    let response = NtkResponse(code: retCode, data: retData, msg: msg, response: response.response, request: rpcRequest, isCache: response.isCache)
                    return response
                } else {
                    throw NtkError.serviceDataTypeInvalid
                }
            }
            // 使用默认的JSONDecoder自动解码
            guard JSONSerialization.isValidJSONObject(data) else {
                // 后端code验证成功，但是没有得到匹配的数据类型
                throw NtkError.jsonInvalid(rpcRequest, sendableResponse)
            }
            let responseData = try JSONSerialization.data(withJSONObject: data)
            
            // 使用运行时类型转换
            if let decodableType = ResponseData.self as? Decodable.Type {
                let decoded = try JSONDecoder().decode(decodableType, from: responseData)
                let fixResponse = NtkResponse(code: retCode, data: decoded as! ResponseData, msg: msg, response: response.response, request: rpcRequest, isCache: response.isCache)
                return fixResponse
            } else {
                throw NtkError.serviceDataTypeInvalid
            }
        } catch let error as DecodingError {
            // decoder字段解析报错，避免崩溃
            throw NtkError.decodeInvalid(error, rpcRequest, sendableResponse)
        } catch {
            // 重新抛出其他错误
            throw error
        }
    }
}
