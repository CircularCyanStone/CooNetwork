import Foundation

/// TFN拦截器链
@TFNActor
struct TFNInterceptorChain {
    private let interceptors: [any iTFNInterceptor]
    private let finalHandler: @Sendable (TFNInterceptorContext) async throws -> any iTFNResponse
    
    init(interceptors: [any iTFNInterceptor], finalHandler: @escaping @Sendable (TFNInterceptorContext) async throws -> any iTFNResponse) {
        // 按优先级排序拦截器，优先级高的（数值小的）先执行
        self.interceptors = interceptors.sorted { $0.priority < $1.priority }
        self.finalHandler = finalHandler
    }
    
    func execute(_ context: TFNInterceptorContext) async throws -> any iTFNResponse {
        return try await buildChain(index: 0)(context)
    }
    
    private func buildChain(index: Int) -> @Sendable (TFNInterceptorContext) async throws -> any iTFNResponse {
        if index >= interceptors.count { return finalHandler }
        
        let currentInterceptor = interceptors[index]
        let nextHandler = TFNNextHandler(handler: buildChain(index: index + 1))
        
        return { context in try await currentInterceptor.intercept(context, next: nextHandler) }
    }
}
