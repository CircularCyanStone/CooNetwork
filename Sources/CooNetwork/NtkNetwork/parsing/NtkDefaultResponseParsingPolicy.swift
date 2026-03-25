import Foundation

struct NtkDefaultResponseParsingPolicy<ResponseData: Sendable & Decodable> {
    typealias ResponseNotifier = @Sendable (any iNtkResponse, NtkInterceptorContext) async throws -> Void

    let validation: iNtkResponseValidation
    let notifyWillValidate: ResponseNotifier
    let notifyDidValidateFail: ResponseNotifier
    let notifyDidComplete: ResponseNotifier

    init(
        validation: iNtkResponseValidation,
        notifyWillValidate: @escaping ResponseNotifier = { _, _ in },
        notifyDidValidateFail: @escaping ResponseNotifier = { _, _ in },
        notifyDidComplete: @escaping ResponseNotifier = { _, _ in }
    ) {
        self.validation = validation
        self.notifyWillValidate = notifyWillValidate
        self.notifyDidValidateFail = notifyDidValidateFail
        self.notifyDidComplete = notifyDidComplete
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
                try await notifyDidComplete(response, context)
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
            try await notifyDidComplete(response, context)
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
        try await notifyWillValidate(response, context)

        guard validation.isServiceSuccess(response) else {
            try await notifyDidValidateFail(response, context)
            throw NtkError.validation(request, response)
        }
    }
}
