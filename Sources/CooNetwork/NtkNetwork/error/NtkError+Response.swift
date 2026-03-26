import Foundation

public struct ResponseFailure: Error, Sendable {
    public enum Reason: Sendable {
        case bodyEmpty
        case invalidResponseType
        case cancelled
        case timedOut
        case transportError
    }

    public struct Context: @unchecked Sendable {
        public let request: iNtkRequest?
        public let clientResponse: NtkClientResponse?
        public let underlyingError: Error?

        public init(
            request: iNtkRequest? = nil,
            clientResponse: NtkClientResponse? = nil,
            underlyingError: Error? = nil
        ) {
            self.request = request
            self.clientResponse = clientResponse
            self.underlyingError = underlyingError
        }
    }

    public let reason: Reason
    public let context: Context?

    public init(reason: Reason, context: Context? = nil) {
        self.reason = reason
        self.context = context
    }
}
