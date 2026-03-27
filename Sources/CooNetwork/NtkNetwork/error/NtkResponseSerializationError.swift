import Foundation

public extension NtkError {
    enum Serialization: Error, Sendable {
        public struct DecodingFailureContext: @unchecked Sendable {
            public let clientResponse: NtkClientResponse?
            public let recoveredResponse: NtkResponse<NtkDynamicData?>?
            public let rawPayload: NtkPayload?
            public let underlyingError: Error?

            public init(
                clientResponse: NtkClientResponse?,
                recoveredResponse: NtkResponse<NtkDynamicData?>?,
                rawPayload: NtkPayload?,
                underlyingError: Error?
            ) {
                self.clientResponse = clientResponse
                self.recoveredResponse = recoveredResponse
                self.rawPayload = rawPayload
                self.underlyingError = underlyingError
            }
        }

        case invalidJSON
        case invalidEnvelope
        case invalidDataPayload(recoveredResponse: NtkResponse<NtkDynamicData?>?)
        case dataDecodingFailed(context: DecodingFailureContext)
        case dataMissing(clientResponse: NtkClientResponse)
        case dataTypeMismatch(underlyingError: Error?)
    }
}
