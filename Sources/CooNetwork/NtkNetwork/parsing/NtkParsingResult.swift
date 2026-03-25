import Foundation

enum NtkParsingResult<ResponseData: Sendable>: Sendable {
    case decoded(
        code: NtkReturnCode,
        msg: String?,
        data: ResponseData?,
        request: iNtkRequest,
        clientResponse: NtkClientResponse,
        isCache: Bool
    )

    case headerRecovered(
        decodeError: DecodingError,
        rawPayload: NtkPayload,
        header: NtkExtractedHeader,
        request: iNtkRequest,
        clientResponse: NtkClientResponse,
        isCache: Bool
    )

    case unrecoverableDecodeFailure(
        decodeError: DecodingError,
        rawPayload: NtkPayload,
        request: iNtkRequest,
        clientResponse: NtkClientResponse,
        isCache: Bool
    )
}
