import Foundation

/// 请求协议，定义了一个网络请求所需的所有基本信息
protocol iTFNRequest: Sendable {
    
    var baseURL: URL { get }
    var path: String { get }
    var method: TFNHTTPMethod { get }
    var parameters: [String: Sendable]? { get }
    var body: Data? { get }
    var headers: [String: String]? { get }
    var cachePolicy: TFNCachePolicy? { get }
    var checkLogin: Bool { get }

    func isServiceSuccess(_ response: any iTFNResponse) -> Bool
}
extension iTFNRequest {
    var method: TFNHTTPMethod {
        .post
    }
    var parameters: [String: Sendable]? {
        nil
    }
    var body: Data? {
        nil
    }
    var headers: [String: String]? {
        nil
    }
    var cachePolicy: TFNCachePolicy? {
        nil
    }
    var checkLogin: Bool {
        true
    }
    var timeoutInterval: TimeInterval? {
        nil
    }
    func isServiceSuccess(_ response: any iTFNResponse) -> Bool {
        response.statusCode.intValue == 0 || response.statusCode.stringValue == "0"
    }
}

