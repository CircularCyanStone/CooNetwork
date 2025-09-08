import Foundation

/// 拦截器优先级枚举
/// 数值越小，优先级越高，越早执行
enum TFNInterceptorPriority: Int, Sendable, Comparable {
    /// 最高优先级 - 用于认证、安全等关键拦截器
    case highest = 100
    /// 高优先级 - 用于URL构建、请求预处理等
    case high = 200
    /// 普通优先级 - 用于日志、监控等通用拦截器
    case normal = 300
    /// 低优先级 - 用于缓存、数据转换等
    case low = 400
    /// 最低优先级 - 用于数据解析等最后处理的拦截器
    case lowest = 500
    
    static func < (lhs: TFNInterceptorPriority, rhs: TFNInterceptorPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 拦截器协议
@TFNActor
protocol iTFNInterceptor: Sendable {
    /// 拦截器优先级，默认为普通优先级
    var priority: TFNInterceptorPriority { get }
    
    func intercept(_ context: TFNInterceptorContext, next: TFNNextHandler) async throws -> any iTFNResponse
}

/// 为拦截器协议提供默认优先级实现
extension iTFNInterceptor {
    var priority: TFNInterceptorPriority { .normal }
}
