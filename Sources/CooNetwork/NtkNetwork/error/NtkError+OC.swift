import Foundation

public let NtkErrorDomain = "NtkErrorDomain"
public let NtkCacheErrorDomain = "NtkCacheErrorDomain"

@objc public enum NtkErrorCode: Int {
    case requestTypeMismatch = 10001
    case requestInvalidRequest = 10002
    case requestUnsupportedRequestType = 10003

    case responseBodyEmpty = 10101
    case responseInvalidResponseType = 10102
    case responseCancelled = 10103
    case responseTimedOut = 10104
    case responseTransportError = 10105

    case serializationInvalidJSON = 10201
    case serializationEnvelopeDecodeFailed = 10202
    case serializationDataDecodeFailed = 10203
    case serializationDataMissing = 10204
    case serializationDataTypeMismatch = 10205

    case validationServiceRejected = 10301

    case clientAFResponseTypeError = 10401
    case clientAFAFError = 10402
    case clientAFUnknown = 10403
}

@objc public enum NtkCacheErrorCode: Int {
    case noCache = 20001
}

@objcMembers
public final class NtkErrorBridge: NSObject {
    public static func bridge(_ error: Error) -> NSError {
        if let nsError = error as NSError?, nsError.domain == NtkErrorDomain || nsError.domain == NtkCacheErrorDomain {
            return nsError
        }

        if let error = error as? NtkError {
            return bridge(error)
        }

        if let error = error as? NtkError.Cache {
            switch error {
            case .noCache:
                return NSError(
                    domain: NtkCacheErrorDomain,
                    code: NtkCacheErrorCode.noCache.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "无缓存数据"]
                )
            }
        }

        let nsError = error as NSError
        return NSError(
            domain: NtkErrorDomain,
            code: NtkErrorCode.responseTransportError.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: nsError.localizedDescription,
                "underlyingError": nsError
            ]
        )
    }

    public static func isCacheError(_ error: NSError) -> Bool {
        error.domain == NtkCacheErrorDomain
    }

    public static func isValidationError(_ error: NSError) -> Bool {
        error.domain == NtkErrorDomain && error.code == NtkErrorCode.validationServiceRejected.rawValue
    }

    public static func isRequestError(_ error: NSError) -> Bool {
        error.domain == NtkErrorDomain && (10001...10099).contains(error.code)
    }

    public static func isResponseError(_ error: NSError) -> Bool {
        error.domain == NtkErrorDomain && (10101...10199).contains(error.code)
    }

    public static func isSerializationError(_ error: NSError) -> Bool {
        error.domain == NtkErrorDomain && (10201...10299).contains(error.code)
    }

    public static func isClientError(_ error: NSError) -> Bool {
        error.domain == NtkErrorDomain && (10401...10499).contains(error.code)
    }

    private static func bridge(_ error: NtkError) -> NSError {
        switch error {
        case let .request(failure):
            return NSError(
                domain: NtkErrorDomain,
                code: requestCode(for: failure.reason).rawValue,
                userInfo: [NSLocalizedDescriptionKey: "请求错误"]
            )

        case let .response(failure):
            return NSError(
                domain: NtkErrorDomain,
                code: responseCode(for: failure.reason).rawValue,
                userInfo: makeUserInfo(
                    description: "响应错误",
                    request: failure.context?.request,
                    clientResponse: failure.context?.clientResponse,
                    underlyingError: failure.context?.underlyingError,
                    rawPayload: nil,
                    recoveredResponse: nil,
                    response: nil
                )
            )

        case let .serialization(failure):
            return NSError(
                domain: NtkErrorDomain,
                code: serializationCode(for: failure.reason).rawValue,
                userInfo: makeUserInfo(
                    description: "序列化错误",
                    request: failure.context.request,
                    clientResponse: failure.context.clientResponse,
                    underlyingError: failure.context.underlyingError,
                    rawPayload: failure.context.rawPayload,
                    recoveredResponse: failure.context.recoveredResponse,
                    response: nil
                )
            )

        case let .validation(failure):
            return NSError(
                domain: NtkErrorDomain,
                code: NtkErrorCode.validationServiceRejected.rawValue,
                userInfo: makeUserInfo(
                    description: "验证失败",
                    request: failure.context.request,
                    clientResponse: nil,
                    underlyingError: nil,
                    rawPayload: nil,
                    recoveredResponse: nil,
                    response: failure.context.response
                )
            )

        case let .client(failure):
            switch failure {
            case let .af(afFailure):
                return NSError(
                    domain: NtkErrorDomain,
                    code: clientAFCode(for: afFailure.reason).rawValue,
                    userInfo: makeUserInfo(
                        description: afFailure.context.message ?? "客户端错误",
                        request: afFailure.context.request,
                        clientResponse: afFailure.context.clientResponse,
                        underlyingError: afFailure.context.underlyingError,
                        rawPayload: nil,
                        recoveredResponse: nil,
                        response: nil
                    )
                )
            }
        }
    }

    private static func makeUserInfo(
        description: String,
        request: iNtkRequest?,
        clientResponse: NtkClientResponse?,
        underlyingError: Error?,
        rawPayload: Data?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?,
        response: (any iNtkResponse)?
    ) -> [String: Any] {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: description]
        if let request { userInfo["request"] = String(describing: request) }
        if let clientResponse { userInfo["clientResponse"] = String(describing: clientResponse) }
        if let recoveredResponse { userInfo["recoveredResponse"] = String(describing: recoveredResponse) }
        if let response { userInfo["response"] = String(describing: response) }
        if let underlyingError { userInfo["underlyingError"] = underlyingError as NSError }
        if let rawPayload { userInfo["rawPayload"] = rawPayload }
        return userInfo
    }

    private static func requestCode(for reason: RequestFailure.Reason) -> NtkErrorCode {
        switch reason {
        case .typeMismatch: return .requestTypeMismatch
        case .invalidRequest: return .requestInvalidRequest
        case .unsupportedRequestType: return .requestUnsupportedRequestType
        }
    }

    private static func responseCode(for reason: ResponseFailure.Reason) -> NtkErrorCode {
        switch reason {
        case .bodyEmpty: return .responseBodyEmpty
        case .invalidResponseType: return .responseInvalidResponseType
        case .cancelled: return .responseCancelled
        case .timedOut: return .responseTimedOut
        case .transportError: return .responseTransportError
        }
    }

    private static func serializationCode(for reason: SerializationFailure.Reason) -> NtkErrorCode {
        switch reason {
        case .invalidJSON: return .serializationInvalidJSON
        case .envelopeDecodeFailed: return .serializationEnvelopeDecodeFailed
        case .dataDecodeFailed: return .serializationDataDecodeFailed
        case .dataMissing: return .serializationDataMissing
        case .dataTypeMismatch: return .serializationDataTypeMismatch
        }
    }

    private static func clientAFCode(for reason: ClientFailure.AF.Reason) -> NtkErrorCode {
        switch reason {
        case .responseTypeError: return .clientAFResponseTypeError
        case .afError: return .clientAFAFError
        case .unknown: return .clientAFUnknown
        }
    }
}
