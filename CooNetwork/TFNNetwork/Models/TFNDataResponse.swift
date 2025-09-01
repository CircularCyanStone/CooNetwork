import Foundation

/// TFN数据响应结构体
struct TFNDataResponse: iTFNResponse {
    typealias DataType = Data
    
    var statusCode: TFNReturnCode = TFNReturnCode(-1)
    let data: Data
    var message: String? { nil }
    let request: any iTFNRequest
    var response: any Sendable
    var isCache: Bool
}
