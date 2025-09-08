import Foundation

/// 响应协议，定义了网络响应的基本结构
protocol iTFNResponse: Sendable {
    associatedtype DataType: Sendable & Decodable
    
    var statusCode: TFNReturnCode { get }
    var message: String? { get }
    var isCache: Bool { get }
    var request: any iTFNRequest { get }
    var data: DataType { get }
    
    /// 原始响应数据
    /// - Returns: 未解析的原始响应数据
    var response: Sendable { get }
}
