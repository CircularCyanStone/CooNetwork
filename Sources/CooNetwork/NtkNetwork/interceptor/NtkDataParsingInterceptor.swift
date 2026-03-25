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
    private let policy: NtkDefaultResponseParsingPolicy<ResponseData>

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
        self.policy = NtkDefaultResponseParsingPolicy(
            validation: validation,
            notifyWillValidate: { response, context in
                for hook in hooks { try await hook.willValidate(response, context: context) }
            },
            notifyDidValidateFail: { response, context in
                for hook in hooks { try await hook.didValidateFail(response, context: context) }
            },
            notifyDidComplete: { response, context in
                for hook in hooks { try await hook.didComplete(response, context: context) }
            }
        )
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
        self.policy = NtkDefaultResponseParsingPolicy(
            validation: validation,
            notifyWillValidate: { response, context in
                for hook in hooks { try await hook.willValidate(response, context: context) }
            },
            notifyDidValidateFail: { response, context in
                for hook in hooks { try await hook.didValidateFail(response, context: context) }
            },
            notifyDidComplete: { response, context in
                for hook in hooks { try await hook.didComplete(response, context: context) }
            }
        )
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

            let result = NtkParsingResult<ResponseData>.decoded(
                code: decoderResponse.code,
                msg: decoderResponse.msg,
                data: decoderResponse.data,
                request: request,
                clientResponse: clientResponse,
                isCache: clientResponse.isCache
            )
            return try await policy.decide(from: result, context: context)

        } catch let error as DecodingError {
            let result: NtkParsingResult<ResponseData>
            if let header = try? decoder.extractHeader(finalPayload, request: request) {
                result = .headerRecovered(
                    decodeError: error,
                    rawPayload: finalPayload,
                    header: header,
                    request: request,
                    clientResponse: clientResponse,
                    isCache: clientResponse.isCache
                )
            } else {
                result = .unrecoverableDecodeFailure(
                    decodeError: error,
                    rawPayload: finalPayload,
                    request: request,
                    clientResponse: clientResponse,
                    isCache: clientResponse.isCache
                )
            }
            return try await policy.decide(from: result, context: context)
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

}
