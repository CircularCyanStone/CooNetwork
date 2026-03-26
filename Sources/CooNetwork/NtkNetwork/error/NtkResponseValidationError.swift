import Foundation

public extension NtkError {
    public enum ValidationError: Error, Sendable {
        case serviceRejected(
            request: any iNtkRequest,
            response: any iNtkResponse
        )
    }
}
