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

    private let dispatcher: NtkParsingHookDispatcher
    private let transformers: [any iNtkResponsePayloadTransforming]
    private let decoder: any iNtkResponsePayloadDecoding<ResponseData, Keys>
    private let policy: NtkDefaultResponseParsingPolicy<ResponseData>

    /// 初始化解析拦截器（使用默认 Data payload decoder）
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = []
    ) {
        let dispatcher = NtkParsingHookDispatcher(hooks: hooks)
        self.dispatcher = dispatcher
        self.transformers = transformers
        self.decoder = NtkDataPayloadDecoder<ResponseData, Keys>()
        self.policy = NtkDefaultResponseParsingPolicy(
            validation: validation,
            dispatcher: dispatcher
        )
    }

    /// 初始化解析拦截器（自定义 payload decoder）
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = [],
        decoder: any iNtkResponsePayloadDecoding<ResponseData, Keys>
    ) {
        let dispatcher = NtkParsingHookDispatcher(hooks: hooks)
        self.dispatcher = dispatcher
        self.transformers = transformers
        self.decoder = decoder
        self.policy = NtkDefaultResponseParsingPolicy(
            validation: validation,
            dispatcher: dispatcher
        )
    }

    public func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        let acquired = try await acquire(context: context, next: next)
        if let passthrough = acquired.typedPassthrough {
            return passthrough
        }

        let prepared = try await prepare(acquired, context: context)
        let interpreted = try await interpret(prepared, context: context)
        return try await decide(interpreted, context: context)
    }

    @NtkActor
    private func acquire(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> AcquiredResponse {
        let response = try await next.handle(context: context)

        if let typedPassthrough = response as? NtkResponse<ResponseData> {
            return AcquiredResponse(typedPassthrough: typedPassthrough)
        }

        guard let clientResponse = response as? NtkClientResponse else {
            throw NtkError.invalidResponseType(response: response)
        }

        return AcquiredResponse(
            request: context.mutableRequest.originalRequest,
            clientResponse: clientResponse
        )
    }

    @NtkActor
    private func prepare(
        _ acquired: AcquiredResponse,
        context: NtkInterceptorContext
    ) async throws -> PreparedPayload {
        guard let request = acquired.request,
              let clientResponse = acquired.clientResponse else {
            throw NtkError.invalidRequest
        }

        if let body = clientResponse.data as? Data, body.isEmpty {
            throw NtkError.responseBodyEmpty(clientResponse: clientResponse)
        }

        let normalizedPayload = try NtkPayload.normalize(from: clientResponse.data)
        let finalPayload = try await transform(normalizedPayload, context: context)
        return PreparedPayload(
            request: request,
            clientResponse: clientResponse,
            payload: finalPayload
        )
    }

    @NtkActor
    private func interpret(
        _ prepared: PreparedPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkInterpretation<ResponseData> {
        do {
            let decoderResponse = try await decoder.decode(prepared.payload, context: context)
            logDecodedHeader(decoderResponse, request: prepared.request)

            await dispatcher.didDecodeHeader(
                retCode: decoderResponse.code.intValue,
                msg: decoderResponse.msg,
                context: context
            )

            let decoded = NtkInterpretation<ResponseData>.Decoded(
                code: decoderResponse.code,
                msg: decoderResponse.msg,
                data: decoderResponse.data,
                request: prepared.request,
                clientResponse: prepared.clientResponse,
                isCache: prepared.clientResponse.isCache
            )
            return .decoded(decoded)
        } catch let error as DecodingError {
            return makeInterpretFailureResult(from: error, prepared: prepared)
        }
    }

    @NtkActor
    private func decide(
        _ interpretation: NtkInterpretation<ResponseData>,
        context: NtkInterceptorContext
    ) async throws -> any iNtkResponse {
        try await policy.decide(from: interpretation, context: context)
    }

    private func logDecodedHeader(
        _ decoderResponse: NtkResponseDecoder<ResponseData, Keys>,
        request: iNtkRequest
    ) {
        logger.debug(
            "[Response] \(request) params=\(request.parameters as [String: any Sendable]? ?? [:]) code=\(decoderResponse.code) msg=\(decoderResponse.msg ?? "")",
            category: .network
        )
    }

    private func makeInterpretFailureResult(
        from error: DecodingError,
        prepared: PreparedPayload
    ) -> NtkInterpretation<ResponseData> {
        let failure = NtkInterpretation<ResponseData>.DecodeFailure(
            decodeError: error,
            rawPayload: prepared.payload,
            header: try? decoder.extractHeader(prepared.payload, request: prepared.request),
            request: prepared.request,
            clientResponse: prepared.clientResponse,
            isCache: prepared.clientResponse.isCache
        )
        return .decodeFailed(failure)
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

    private struct AcquiredResponse {
        let typedPassthrough: NtkResponse<ResponseData>?
        let request: iNtkRequest?
        let clientResponse: NtkClientResponse?

        init(typedPassthrough: NtkResponse<ResponseData>) {
            self.typedPassthrough = typedPassthrough
            self.request = nil
            self.clientResponse = nil
        }

        init(request: iNtkRequest, clientResponse: NtkClientResponse) {
            self.typedPassthrough = nil
            self.request = request
            self.clientResponse = clientResponse
        }
    }

    private struct PreparedPayload {
        let request: iNtkRequest
        let clientResponse: NtkClientResponse
        let payload: NtkPayload
    }

}
