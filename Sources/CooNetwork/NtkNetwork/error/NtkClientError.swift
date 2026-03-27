import Foundation

public extension NtkError {
    enum Client: Error, @unchecked Sendable {
        public struct ExternalContext: @unchecked Sendable {
            public let request: (any iNtkRequest)?
            public let clientResponse: NtkClientResponse?
            public let underlyingError: Error?
            public let message: String?

            public init(
                request: (any iNtkRequest)?,
                clientResponse: NtkClientResponse?,
                underlyingError: Error?,
                message: String?
            ) {
                self.request = request
                self.clientResponse = clientResponse
                self.underlyingError = underlyingError
                self.message = message
            }
        }

        case external(
            reason: any Error,
            context: ExternalContext
        )
    }
}
