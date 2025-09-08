import Foundation

/// TFN下一个处理器结构体
@TFNActor
struct TFNNextHandler: Sendable {
    private let handler: @Sendable (TFNInterceptorContext) async throws -> any iTFNResponse
    
    init(handler: @escaping @Sendable (TFNInterceptorContext) async throws -> any iTFNResponse) {
        self.handler = handler
    }
    
    func proceed(_ context: TFNInterceptorContext) async throws -> any iTFNResponse {
        return try await handler(context)
    }
}
