import Foundation

public struct ValidationFailure: Error, Sendable {
    public enum Reason: Sendable {
        case serviceRejected
    }

    public struct Context: @unchecked Sendable {
        public let request: iNtkRequest
        public let response: any iNtkResponse

        public init(request: iNtkRequest, response: any iNtkResponse) {
            self.request = request
            self.response = response
        }
    }

    public let reason: Reason
    public let context: Context

    public init(reason: Reason, context: Context) {
        self.reason = reason
        self.context = context
    }
}
