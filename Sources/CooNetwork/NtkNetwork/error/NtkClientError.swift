import Foundation

public enum NtkClientError: Error, @unchecked Sendable {
    case external(
        reason: any Error,
        request: (any iNtkRequest)?,
        clientResponse: NtkClientResponse?,
        underlyingError: Error?,
        message: String?
    )
}
