import Foundation

public extension NtkError {
    public enum Client: Error, @unchecked Sendable {
        case external(
            reason: any Error,
            request: (any iNtkRequest)?,
            clientResponse: NtkClientResponse?,
            underlyingError: Error?,
            message: String?
        )
    }
}
