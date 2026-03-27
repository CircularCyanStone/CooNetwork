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
        context: NtkInterceptorContext
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
                let response = NtkResponse<ResponseData?>(
                    code: decoded.code,
                    data: nil,
                    msg: decoded.msg,
                    response: decoded.clientResponse,
                    request: decoded.request,
                    isCache: decoded.isCache
                )
                try await validateServiceSuccess(response, request: decoded.request, context: context)
                throw NtkError.Serialization.dataMissing(
                    request: decoded.request,
                    clientResponse: decoded.clientResponse,
                    recoveredResponse: nil
                )
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
                throw NtkError.Serialization.dataDecodingFailed(
                    request: failure.request,
                    clientResponse: failure.clientResponse,
                    recoveredResponse: recoveredResponse,
                    rawPayload: failure.clientResponse.data as? Data,
                    underlyingError: failure.decodeError
                )
            }
            throw NtkError.Serialization.dataDecodingFailed(
                request: failure.request,
                clientResponse: failure.clientResponse,
                recoveredResponse: nil,
                rawPayload: failure.clientResponse.data as? Data,
                underlyingError: failure.decodeError
            )
        }
    }

    private func validateServiceSuccess(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkInterceptorContext
    ) async throws {
        await dispatcher.willValidate(response, context: context)

        guard validation.isServiceSuccess(response) else {
            await dispatcher.didValidateFail(response, context: context)
            throw NtkError.Validation.serviceRejected(
                request: request,
                response: response
            )
        }
    }
}
