import Foundation

/// 响应数据映射键协议
protocol iTFNResponseMapKeys: Sendable {
    static var statusCodeKey: String { get }
    static var messageKey: String { get }
    static var dataKey: String { get }
}

struct TFNResponseMapKeys: iTFNResponseMapKeys {
   
    static var statusCodeKey: String {
        "code"
    }
    
    static var messageKey: String {
        "msg"
    }
    
    static var dataKey: String {
        "data"
    }
}
