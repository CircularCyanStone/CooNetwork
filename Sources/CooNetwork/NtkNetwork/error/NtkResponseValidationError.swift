import Foundation

public extension NtkError {
    enum Validation: Error, Sendable {
        case serviceRejected(
            request: any iNtkRequest,
            response: any iNtkResponse
        )
    }
}
