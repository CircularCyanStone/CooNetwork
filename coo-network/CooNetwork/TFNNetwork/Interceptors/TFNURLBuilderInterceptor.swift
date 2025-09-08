import Foundation

/// TFN URL构建拦截器
struct TFNURLBuilderInterceptor: iTFNInterceptor {
    /// URL构建拦截器使用高优先级，确保在其他拦截器之前执行
    var priority: TFNInterceptorPriority { .high }
    
    func intercept(_ context: TFNInterceptorContext, next: TFNNextHandler) async throws -> any iTFNResponse {
        // The URL is now built in the URLRequest extension, so this interceptor might seem redundant.
        // However, it's kept for conceptual clarity in the chain and for potential future URL manipulations.
        return try await next.proceed(context)
    }
}
