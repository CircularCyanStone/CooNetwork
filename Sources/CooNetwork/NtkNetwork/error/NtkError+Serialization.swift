import Foundation

public struct SerializationFailure: Error, Sendable {
    public enum Reason: Sendable {
        case invalidJSON
        case envelopeDecodeFailed
        case dataDecodeFailed
        case dataMissing
        case dataTypeMismatch
    }

    public enum Stage: Sendable {
        case json
        case envelope
        case data
        case model
    }

    public struct Context: @unchecked Sendable {
        public let request: iNtkRequest?
        public let clientResponse: NtkClientResponse?
        public let recoveredResponse: NtkResponse<NtkDynamicData?>?
        public let rawPayload: Data?
        public let payloadSnapshot: NtkDynamicData?
        public let underlyingError: Error?
        public let stage: Stage

        public init(
            request: iNtkRequest? = nil,
            clientResponse: NtkClientResponse? = nil,
            recoveredResponse: NtkResponse<NtkDynamicData?>? = nil,
            rawPayload: Data? = nil,
            payloadSnapshot: NtkDynamicData? = nil,
            underlyingError: Error? = nil,
            stage: Stage
        ) {
            self.request = request
            self.clientResponse = clientResponse
            self.recoveredResponse = recoveredResponse
            self.rawPayload = rawPayload
            self.payloadSnapshot = payloadSnapshot
            self.underlyingError = underlyingError
            self.stage = stage
        }
    }

    public let reason: Reason
    public let context: Context

    public init(reason: Reason, context: Context) {
        self.reason = reason
        self.context = context
    }
}
