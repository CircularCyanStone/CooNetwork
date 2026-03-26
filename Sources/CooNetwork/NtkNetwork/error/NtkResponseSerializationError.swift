import Foundation

public extension NtkError {
    public enum SerializationError: Error, Sendable {
    case invalidJSON(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        rawPayload: Data?
    )

    case invalidEnvelope(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        rawPayload: Data?
    )

    case invalidDataPayload(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?
    )

    case envelopeDecodingFailed(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        rawPayload: Data?,
        underlyingError: Error?
    )

    case dataDecodingFailed(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?,
        rawPayload: Data?,
        underlyingError: Error?
    )

    case dataMissing(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?
    )

    case dataTypeMismatch(
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        recoveredResponse: NtkResponse<NtkDynamicData?>?,
        underlyingError: Error?
    )
    }
}
