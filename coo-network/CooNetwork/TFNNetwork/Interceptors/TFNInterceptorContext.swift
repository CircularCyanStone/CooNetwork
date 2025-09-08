import Foundation

/// TFN拦截器上下文结构体
struct TFNInterceptorContext: Sendable {
    
    var mutableRequest: TFNMutableRequest
    
    let client: any iTFNClient
    
    let isCache: Bool
    
}
