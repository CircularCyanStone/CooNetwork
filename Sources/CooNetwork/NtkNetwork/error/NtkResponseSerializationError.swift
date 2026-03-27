import Foundation

public extension NtkError {
    enum Serialization: Error, Sendable {
        public struct DecodingFailureContext: @unchecked Sendable {
            public let clientResponse: NtkClientResponse?
            public let recoveredResponse: NtkResponse<NtkDynamicData?>?
            public let rawPayload: Data?
            public let underlyingError: Error?

            public init(
                clientResponse: NtkClientResponse?,
                recoveredResponse: NtkResponse<NtkDynamicData?>?,
                rawPayload: Data?,
                underlyingError: Error?
            ) {
                self.clientResponse = clientResponse
                self.recoveredResponse = recoveredResponse
                self.rawPayload = rawPayload
                self.underlyingError = underlyingError
            }
        }

        case invalidJSON(rawPayload: Data?)
        case invalidEnvelope(rawPayload: Data?)
        case invalidDataPayload(recoveredResponse: NtkResponse<NtkDynamicData?>?)
        case envelopeDecodingFailed(
            clientResponse: NtkClientResponse?,
            rawPayload: Data?,
            underlyingError: Error?
        )
        case dataDecodingFailed(context: DecodingFailureContext)
        case dataMissing(clientResponse: NtkClientResponse)
        case dataTypeMismatch(underlyingError: Error?)
    }
}
