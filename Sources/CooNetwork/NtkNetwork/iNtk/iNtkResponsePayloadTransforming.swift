import Foundation

public protocol iNtkResponsePayloadTransforming: Sendable {
    func transform(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkPayload
}
