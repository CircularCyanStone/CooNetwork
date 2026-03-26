import Foundation

public struct RequestFailure: Error, Sendable {
    public enum Reason: Sendable {
        case typeMismatch
        case invalidRequest
        case unsupportedRequestType
    }

    public let reason: Reason

    public init(reason: Reason) {
        self.reason = reason
    }
}
