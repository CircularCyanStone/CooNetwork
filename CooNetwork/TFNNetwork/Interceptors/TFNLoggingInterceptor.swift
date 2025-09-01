import Foundation
import OSLog

/// TFN日志拦截器
struct TFNLoggingInterceptor: iTFNInterceptor {
    private let logger = Logger(subsystem: "com.taichat.network", category: "TFNNetwork")
    
    /// 日志拦截器使用普通优先级（默认优先级）
    var priority: TFNInterceptorPriority { .lowest }

    func intercept(_ context: TFNInterceptorContext, next: TFNNextHandler) async throws -> any iTFNResponse {
        let startTime = Date()
        let request = context.mutableRequest
        
        logger.info("🚀 [TFN] Request Start: \(request.method.rawValue) \(request.baseURL.appendingPathComponent(request.path).absoluteString)")
        if let headers = request.headers, !headers.isEmpty { logger.debug("  Headers: \(headers, privacy: .auto)") }
        if let parameters = request.parameters, !parameters.isEmpty { logger.debug("  Parameters: \(String(describing: parameters), privacy: .auto)") }
        
        do {
            let response = try await next.proceed(context)
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ [TFN] Response Success: \(response.statusCode.stringValue) (\(String(format: "%.2fs", duration)))")
            return response
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let errorDesc = (error as? TFNError)?.localizedDescription ?? error.localizedDescription
            logger.error("❌ [TFN] Response Error: \(errorDesc) (\(String(format: "%.2fs", duration)))")
            throw error
        }
    }
}
