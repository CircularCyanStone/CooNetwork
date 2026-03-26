import Foundation

public enum ClientFailure: Error, Sendable {
    case af(AF)

    public struct AF: Error, Sendable {
        public enum Reason: Sendable {
            case responseTypeError
            case afError
            case unknown
        }

        public struct Context: @unchecked Sendable {
            public let request: iNtkRequest?
            public let clientResponse: NtkClientResponse?
            public let underlyingError: Error?
            public let message: String?

            public init(
                request: iNtkRequest? = nil,
                clientResponse: NtkClientResponse? = nil,
                underlyingError: Error? = nil,
                message: String? = nil
            ) {
                self.request = request
                self.clientResponse = clientResponse
                self.underlyingError = underlyingError
                self.message = message
            }
        }

        public let reason: Reason
        public let context: Context

        public init(reason: Reason, context: Context) {
            self.reason = reason
            self.context = context
        }
    }
}
