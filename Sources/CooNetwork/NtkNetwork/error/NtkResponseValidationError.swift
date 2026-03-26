import Foundation

public extension NtkError {
    enum ValidationError: Error, Sendable {
        case serviceRejected(
            request: any iNtkRequest,
            response: any iNtkResponse
        )
    }
}
