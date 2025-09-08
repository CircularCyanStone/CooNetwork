import Foundation

/// TFN监控拦截器
/// 用于收集请求性能数据、错误统计等监控信息
struct TFNMonitoringInterceptor: iTFNInterceptor {
    /// 监控拦截器使用普通优先级
    var priority: TFNInterceptorPriority { .normal }
    
    func intercept(_ context: TFNInterceptorContext, next: TFNNextHandler) async throws -> any iTFNResponse {
        let startTime = Date()
        let requestURL = context.mutableRequest.baseURL.appendingPathComponent(context.mutableRequest.path).absoluteString
        
        print("📊 [TFN] Monitoring - Request started: \(requestURL)")
        
        do {
            let response = try await next.proceed(context)
            let duration = Date().timeIntervalSince(startTime)
            
            // 记录成功的请求监控数据
            print("📊 [TFN] Monitoring - Request completed successfully in \(String(format: "%.3f", duration))s")
            
            // 这里可以添加更多监控逻辑，如：
            // - 发送性能数据到监控系统
            // - 记录请求成功率
            // - 统计API调用频率等
            
            return response
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            // 记录失败的请求监控数据
            print("📊 [TFN] Monitoring - Request failed in \(String(format: "%.3f", duration))s: \(error.localizedDescription)")
            
            // 这里可以添加错误监控逻辑，如：
            // - 发送错误信息到监控系统
            // - 统计错误率
            // - 触发告警等
            
            throw error
        }
    }
}
