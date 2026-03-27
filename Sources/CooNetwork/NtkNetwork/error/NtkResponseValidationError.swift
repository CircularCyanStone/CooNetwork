import Foundation

public extension NtkError {
    enum Validation: Error, Sendable {
        case serviceRejected(response: any iNtkResponse)
    }
}
