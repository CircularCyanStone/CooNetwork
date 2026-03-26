import Foundation

public enum NtkResponseValidationError: Error, Sendable {
    case serviceRejected(
        request: any iNtkRequest,
        response: any iNtkResponse
    )
}
