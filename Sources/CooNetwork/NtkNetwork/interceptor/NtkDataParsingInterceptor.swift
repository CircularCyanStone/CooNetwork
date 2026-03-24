//
//  NtkDataParsingInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation

// 通用响应解析拦截器，通过 payload transformer + decoder 支持多种数据源与前置改造。

public struct NtkDataParsingInterceptor<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkResponseParser {

    public let validation: iNtkResponseValidation
    private let hooks: [any iNtkParsingHooks]
    private let transformers: [any iNtkResponsePayloadTransforming]
    private let decoder: any iNtkResponsePayloadDecoding<ResponseData, Keys>

    /// 初始化解析拦截器（使用默认 Data payload decoder）
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = []
    ) {
        self.validation = validation
        self.hooks = hooks
        self.transformers = transformers
        self.decoder = NtkDataPayloadDecoder<ResponseData, Keys>()
    }

    /// 初始化解析拦截器（自定义 payload decoder）
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = [],
        decoder: any iNtkResponsePayloadDecoding<ResponseData, Keys>
    ) {
        self.validation = validation
        self.hooks = hooks
        self.transformers = transformers
        self.decoder = decoder
    }

    public func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)

        if let ntkResponse = response as? NtkResponse<ResponseData> {
            return ntkResponse
        }

        guard let clientResponse = response as? NtkClientResponse else {
            throw NtkError.typeMismatch
        }
        let request = context.mutableRequest.originalRequest

        let normalizedPayload = try NtkPayload.normalize(from: clientResponse.data)
        let finalPayload = try await transform(normalizedPayload, context: context)

        do {
            let decoderResponse = try await decoder.decode(finalPayload, context: context)

            logger.debug(
                """
                ---------------------Data response start-------------------------
                \(request)
                参数：\(request.parameters as [String: any Sendable]? ?? [:])
                code: \(decoderResponse.code)  msg: \(decoderResponse.msg ?? "")
                ---------------------Data response end-------------------------
                """,
                category: .network
            )

            for hook in hooks {
                try await hook.didDecodeHeader(
                    retCode: decoderResponse.code.intValue,
                    msg: decoderResponse.msg,
                    context: context
                )
            }

            if ResponseData.self is NtkNever.Type {
                let fixResponse = NtkResponse(
                    code: decoderResponse.code,
                    data: NtkNever() as! ResponseData,
                    msg: decoderResponse.msg,
                    response: clientResponse,
                    request: request,
                    isCache: clientResponse.isCache
                )
                try await runValidation(fixResponse, request: request, context: context)
                for hook in hooks { try await hook.didComplete(fixResponse, context: context) }
                return fixResponse
            }

            guard let retData = decoderResponse.data else {
                let optionalResponse = NtkResponse<ResponseData?>(
                    code: decoderResponse.code,
                    data: nil,
                    msg: decoderResponse.msg,
                    response: clientResponse,
                    request: request,
                    isCache: clientResponse.isCache
                )
                try await runValidation(optionalResponse, request: request, context: context)
                throw NtkError.serviceDataEmpty
            }

            let fixResponse = NtkResponse(
                code: decoderResponse.code,
                data: retData,
                msg: decoderResponse.msg,
                response: clientResponse,
                request: request,
                isCache: clientResponse.isCache
            )
            try await runValidation(fixResponse, request: request, context: context)
            for hook in hooks { try await hook.didComplete(fixResponse, context: context) }
            return fixResponse

        } catch let error as DecodingError {
            if let header = try? decoder.extractHeader(finalPayload, request: request) {
                let errResponse = NtkResponse<NtkDynamicData?>(
                    code: header.code,
                    data: header.data,
                    msg: header.msg,
                    response: clientResponse,
                    request: request,
                    isCache: clientResponse.isCache
                )
                try await runValidation(errResponse, request: request, context: context)
            }
            throw NtkError.decodeInvalid(error, clientResponse.data, request)
        }
    }

    private func transform(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkPayload {
        var current = payload
        for transformer in transformers {
            current = try await transformer.transform(current, context: context)
        }
        return current
    }

    private func runValidation(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkInterceptorContext
    ) async throws {
        for hook in hooks { try await hook.willValidate(response, context: context) }
        try await validate(response, request: request, context: context)
    }

    private func validate(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkInterceptorContext
    ) async throws {
        guard validation.isServiceSuccess(response) else {
            for hook in hooks {
                try await hook.didValidateFail(response, context: context)
            }
            throw NtkError.validation(request, response)
        }
    }
}
