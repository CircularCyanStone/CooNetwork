//
//  AFDataParsingInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

// 用于解析网络工具返回的直接就是 Data类型的 数据解析工具。

#if !COCOAPODS
import CooNetwork
#endif
import Foundation
import Alamofire

/// 基于原始 Data 的响应解析拦截器
/// 结合 TFNDataParsingInterceptor 的直解优点与 AF 响应校验/键映射能力
public struct AFDataParsingInterceptor<ResponseData: Sendable & Decodable, Keys: iNtkResponseMapKeys>: iNtkInterceptor {

    /// 初始化 Data 解析拦截器
    public init() {}

    /// 拦截响应并解析原始 Data 为目标类型
    public func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)

        // 如果已经是目标类型，直接返回
        if let ntkResponse = response as? NtkResponse<ResponseData> {
            return ntkResponse
        }

        // 期待拿到客户端原始响应
        guard let clientResponse = response as? NtkClientResponse else {
            throw NtkError.typeMismatch
        }
        guard let afRequest = context.mutableRequest.originalRequest as? iAFRequest else {
            fatalError("request must be iAFRequest type")
        }

        // 兼容两种携带位置：优先使用 response，其次使用 data
        let rawData: Data
        if let d = clientResponse.data as? Data {
            rawData = d
        } else if let d = clientResponse.response as? Data {
            rawData = d
        } else {
            throw NtkError.typeMismatch
        }

            do {
                let jsonObject = try JSONSerialization.jsonObject(with: rawData)
                logger.debug(
                    """
                    ---------------------AF response start-------------------------
                    \(afRequest)
                    \(afRequest.isEncrypt ? "加密接口" : "")
                    \(afRequest.checkLogin ? "token接口" : "")
                    参数：\(afRequest.parameters as [String: any Sendable]? ?? [:])
                    响应：\(jsonObject)
                    ---------------------AF response end-------------------------
                    """,
                    category: .network
                )
            } catch {
                logger.error("response json error \(error)", category: .network)
            }

        do {
            if rawData.isEmpty {
                /// http response 响应体就是个空的.
                throw NtkError.responseBodyEmpty(afRequest, clientResponse)
            }
            
            // 直接使用 JSONDecoder 从原始 Data 解码为标准 {code, data, msg} 结构
            let decoderResponse = try JSONDecoder().decode(
                NtkResponseDecoder<ResponseData?, Keys>.self,
                from: rawData
            )

            // 1. NtkNever：不需要数据内容
            if ResponseData.self is NtkNever.Type {
                let fixResponse = NtkResponse(
                    code: decoderResponse.code,
                    data: NtkNever() as! ResponseData,
                    msg: decoderResponse.msg,
                    response: clientResponse,
                    request: afRequest,
                    isCache: clientResponse.isCache
                )
                try validate(fixResponse, request: afRequest, validation: context.validation)
                return fixResponse
            }

            // 2. 常规数据：data 不为空
            if let retData = decoderResponse.data {
                let fixResponse = NtkResponse(
                    code: decoderResponse.code,
                    data: retData,
                    msg: decoderResponse.msg,
                    response: clientResponse,
                    request: afRequest,
                    isCache: clientResponse.isCache
                )
                try validate(fixResponse, request: afRequest, validation: context.validation)
                return fixResponse
            }
           
            // 3. 常规数据：data 为 nil
            // 先以 Optional 形态进行业务校验，因为业务校验可能只看 code
            let optionalResponse = NtkResponse<ResponseData?>(
                code: decoderResponse.code,
                data: nil,
                msg: decoderResponse.msg,
                response: clientResponse,
                request: afRequest,
                isCache: clientResponse.isCache
            )
            // 校验不通过直接抛 validation 错误
            try validate(optionalResponse, request: afRequest, validation: context.validation)
            
            // 校验通过但没有数据，抛出数据为空错误
            throw NtkError.serviceDataEmpty
            
        } catch let error as DecodingError {
            // 字段解析错误
            throw NtkError.decodeInvalid(error, rawData, afRequest)
        } catch {
            // 其他错误透传
            throw error
        }
    }
    
    // MARK: - Private Helper
    
    /// 统一业务校验逻辑
    private func validate(_ response: any iNtkResponse, request: iNtkRequest, validation: iNtkResponseValidation) throws {
        let serviceOK = validation.isServiceSuccess(response)
        if !serviceOK {
            throw NtkError.validation(request, response)
        }
    }
}
