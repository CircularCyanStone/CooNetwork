//
//  AFResponseParsingInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import CooNetwork
import Foundation

protocol AFResponseParsingCustomHander {
    func handle(
        _ sendableResponse: [String: any Sendable],
        response: inout NtkClientResponse,
        request: iAFRequest,
        context: NtkInterceptorContext
    ) throws -> [String: any Sendable]
}

/// AF接口返回值的处理拦截器，用于服务器json数据的解析。
public struct AFResponseParsingInterceptor<
    ResponseData: Sendable,
    Keys: iNtkResponseMapKeys
>: iNtkInterceptor {
    
    /// AFResponseParsingInterceptor默认只处理标准的{code, data, msg}格式的json。
    /// 对于非标准的json，该属性用于自定义的前置处理。
    /// 统一为标准json格式后，方可继续使用handleNormal方法处理。
    let customHandler: AFResponseParsingCustomHander?
    
    init(customHandler: AFResponseParsingCustomHander? = nil) {
        self.customHandler = customHandler
    }
    
    public func intercept(context: NtkInterceptorContext, next: any NtkRequestHandler)
        async throws -> any iNtkResponse
    {
        let response = try await next.handle(context: context)
        guard var clientResponse = response as? NtkClientResponse else {
            if let ntkResponse = response as? NtkResponse<ResponseData> {
                return ntkResponse
            }
            fatalError("AFClient func execute() result type error ")
        }
        guard
            let afRequest = context.mutableRequest.originalRequest
                as? iAFRequest
        else {
            fatalError("request must be iAFRequest type")
        }

        guard
            let sendableResponse = clientResponse.response
                as? [String: Sendable]
        else {
            throw NtkError.AF.responseTypeError
        }
        
        if let customHandler {
            let customeRespose = try customHandler.handle(sendableResponse, response: &clientResponse, request: afRequest, context: context)
            return try handleNormal(
                customeRespose,
                response: &clientResponse,
                request: afRequest,
                validation: context.validation
            )
        }
        
        return try handleNormal(
            sendableResponse,
            response: &clientResponse,
            request: afRequest,
            validation: context.validation
        )
    }
}

extension AFResponseParsingInterceptor {

    public func handleNormal(
        _ sendableResponse: [String: Sendable],
        response: inout NtkClientResponse,
        request: iAFRequest,
        validation: iNtkResponseValidation
    ) throws -> NtkResponse<ResponseData> {

        // 使用 NtkLogger (如果可用) 或标准的 debugPrint，避免生产环境污染
        #if DEBUG
        print(
            """
            ---------------------AF response start-------------------------
            \(request)
            \(request.isEncrypt ? "加密接口" : "")
            \(request.checkLogin ? "token接口" : "")
            参数：\(request.parameters as [String: any Sendable]? ?? [:])
            响应：\(sendableResponse)
            ---------------------AF response end-------------------------
            """
        )
#endif // DEBUG

        let code = sendableResponse[Keys.code]
        let retCode = NtkReturnCode(code)
        /// 更新retCode
        response.updateCode(retCode)
        let msg = sendableResponse[Keys.msg] as? String
        
        let serviceOK = validation.isServiceSuccess(response)
        if !serviceOK {
            /// 服务端校验失败，抛出验证错误
            let fixResponse = NtkResponse(
                code: retCode,
                data: response.data,
                msg: msg,
                response: response,
                request: request,
                isCache: response.isCache
            )
            throw NtkError.validation(response.request, fixResponse)
        }

        /// 服务端校验通过，返回响应
        if ResponseData.self is NtkNever.Type {
            // 用户期待的数据类型就是Never，不需要数据
            let fixResponse = NtkResponse(
                code: retCode,
                data: NtkNever() as! ResponseData,
                msg: msg,
                response: response,
                request: request,
                isCache: response.isCache
            )
            return fixResponse
        }

        guard var data = sendableResponse[Keys.data] else {
            throw NtkError.serviceDataEmpty
        }
        data = request.unwrapRetureData(data)

        do {
            // 检查是否启用自定义响应数据解码
            var enableCustomResponseDataDecode: Bool = request.enableCustomRetureDataDecode
            
            // 基础类型默认开启自定义解码
            if !enableCustomResponseDataDecode {
                if ResponseData.self is String.Type
                    || ResponseData.self is Bool.Type
                    || ResponseData.self is Int.Type
                    || ResponseData.self is [String: Sendable].Type
                {
                    enableCustomResponseDataDecode = true
                }
            }

            if enableCustomResponseDataDecode {
                // 使用自定义解码器
                if let retData = try request.customRetureDataDecode(data) as? ResponseData {
                    let response = NtkResponse(
                        code: retCode,
                        data: retData,
                        msg: msg,
                        response: response.response,
                        request: request,
                        isCache: response.isCache
                    )
                    return response
                } else {
                    throw NtkError.serviceDataTypeInvalid
                }
            }
            
            // 使用默认的JSONDecoder自动解码
            guard JSONSerialization.isValidJSONObject(data) else {
                // 后端code验证成功，但是没有得到匹配的数据类型
                throw NtkError.jsonInvalid(request, sendableResponse)
            }
            let responseData = try JSONSerialization.data(withJSONObject: data)

            // 使用运行时类型转换
            if let decodableType = ResponseData.self as? Decodable.Type {
                let decoded = try JSONDecoder().decode(
                    decodableType,
                    from: responseData
                )
                let fixResponse = NtkResponse(
                    code: retCode,
                    data: decoded as! ResponseData,
                    msg: msg,
                    response: response.response,
                    request: request,
                    isCache: response.isCache
                )
                return fixResponse
            } else {
                throw NtkError.serviceDataTypeInvalid
            }
        } catch let error as DecodingError {
            // decoder字段解析报错，避免崩溃
            throw NtkError.decodeInvalid(error, sendableResponse, request)
        } catch {
            // 重新抛出其他错误
            throw error
        }
    }
}
