import Foundation

struct NtkDefaultResponseParsingPolicy<ResponseData: Sendable & Decodable> {
    let validation: iNtkResponseValidation
    let dispatcher: NtkParsingHookDispatcher

    init(
        validation: iNtkResponseValidation,
        dispatcher: NtkParsingHookDispatcher = NtkParsingHookDispatcher()
    ) {
        self.validation = validation
        self.dispatcher = dispatcher
    }

    func decide(
        from interpretation: NtkInterpretation<ResponseData>,
        context: NtkParsingContext
    ) async throws -> any iNtkResponse {
        switch interpretation {
        case let .decoded(decoded):
            if ResponseData.self is NtkNever.Type {
                let response = NtkResponse(
                    code: decoded.code,
                    data: NtkNever() as! ResponseData,
                    msg: decoded.msg,
                    response: decoded.clientResponse,
                    request: decoded.request,
                    isCache: decoded.isCache
                )
                try await validateServiceSuccess(response, request: decoded.request, context: context)
                await dispatcher.didComplete(response, context: context)
                return response
            }

            guard let data = decoded.data else {
                let validationResponse = NtkResponse<ResponseData?>(
                    code: decoded.code,
                    data: decoded.data,
                    msg: decoded.msg,
                    response: decoded.clientResponse,
                    request: decoded.request,
                    isCache: decoded.isCache
                )
                try await validateServiceSuccess(validationResponse, request: decoded.request, context: context)
                // 如果 validation 通过，说明 data=null 是合法响应，直接返回
                await dispatcher.didComplete(validationResponse, context: context)
                return validationResponse
            }

            let response = NtkResponse(
                code: decoded.code,
                data: data,
                msg: decoded.msg,
                response: decoded.clientResponse,
                request: decoded.request,
                isCache: decoded.isCache
            )
            try await validateServiceSuccess(response, request: decoded.request, context: context)
            await dispatcher.didComplete(response, context: context)
            return response

        case let .decodeFailed(failure):
            if let header = failure.header {
                let recoveredResponse = NtkResponse<NtkDynamicData?>(
                    code: header.code,
                    data: header.data,
                    msg: header.msg,
                    response: failure.clientResponse,
                    request: failure.request,
                    isCache: failure.isCache
                )
                try await validateServiceSuccess(recoveredResponse, request: failure.request, context: context)
                logDecodingFailure(request: failure.request, error: failure.decodeError)
                throw NtkError.Serialization.dataDecodingFailed(
                    context: .init(
                        clientResponse: failure.clientResponse,
                        recoveredResponse: recoveredResponse,
                        rawPayload: failure.rawPayload,
                        underlyingError: failure.decodeError
                    )
                )
            }
            logDecodingFailure(request: failure.request, error: failure.decodeError)
            throw NtkError.Serialization.dataDecodingFailed(
                context: .init(
                    clientResponse: failure.clientResponse,
                    recoveredResponse: nil,
                    rawPayload: failure.rawPayload,
                    underlyingError: failure.decodeError
                )
            )
        }
    }

    private func validateServiceSuccess(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkParsingContext
    ) async throws {
        await dispatcher.willValidate(response, context: context)

        guard validation.isServiceSuccess(response) else {
            await dispatcher.didValidateFail(response, context: context)
            logger.error(
                "响应业务校验失败：requestID=\(context.request.instanceIdentifier.uuidString) code=\(response.code)；影响=响应不会返回给调用方。",
                category: .network
            )
            throw NtkError.Validation.serviceRejected(response: response)
        }
    }

    private func logDecodingFailure(request: iNtkRequest, error: DecodingError) {
        logger.error(
            "响应数据解码失败：method=\(request.method.rawValue)，原因=\(String(reflecting: type(of: error)))；影响=无法生成业务响应，调用方将收到失败结果。",
            category: .network
        )
    }
}
