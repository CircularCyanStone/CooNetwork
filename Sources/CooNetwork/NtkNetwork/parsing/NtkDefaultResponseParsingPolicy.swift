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
        from result: NtkParsingResult<ResponseData>,
        context: NtkInterceptorContext
    ) async throws -> any iNtkResponse {
        switch result {
        case let .decoded(code, msg, data, request, clientResponse, isCache):
            if ResponseData.self is NtkNever.Type {
                let response = NtkResponse(
                    code: code,
                    data: NtkNever() as! ResponseData,
                    msg: msg,
                    response: clientResponse,
                    request: request,
                    isCache: isCache
                )
                try await validate(response, request: request, context: context)
                await dispatcher.didComplete(response, context: context)
                return response
            }

            guard let data else {
                let response = NtkResponse<ResponseData?>(
                    code: code,
                    data: nil,
                    msg: msg,
                    response: clientResponse,
                    request: request,
                    isCache: isCache
                )
                try await validate(response, request: request, context: context)
                throw NtkError.serviceDataEmpty
            }

            let response = NtkResponse(
                code: code,
                data: data,
                msg: msg,
                response: clientResponse,
                request: request,
                isCache: isCache
            )
            try await validate(response, request: request, context: context)
            await dispatcher.didComplete(response, context: context)
            return response

        case let .headerRecovered(decodeError, _, header, request, clientResponse, isCache):
            let response = NtkResponse<NtkDynamicData?>(
                code: header.code,
                data: header.data,
                msg: header.msg,
                response: clientResponse,
                request: request,
                isCache: isCache
            )
            try await validate(response, request: request, context: context)
            throw NtkError.decodeInvalid(decodeError, clientResponse.data, request)

        case let .unrecoverableDecodeFailure(decodeError, _, request, clientResponse, _):
            throw NtkError.decodeInvalid(decodeError, clientResponse.data, request)
        }
    }

    private func validate(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkInterceptorContext
    ) async throws {
        await dispatcher.willValidate(response, context: context)

        guard validation.isServiceSuccess(response) else {
            await dispatcher.didValidateFail(response, context: context)
            throw NtkError.validation(request, response)
        }
    }
}
