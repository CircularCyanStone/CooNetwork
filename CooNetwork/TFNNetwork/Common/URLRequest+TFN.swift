import Foundation
import Alamofire

/// URLRequest扩展，支持从TFN请求创建
extension URLRequest {
    init(from tfnRequest: any iTFNRequest) throws {
        let url = tfnRequest.baseURL.appendingPathComponent(tfnRequest.path)
        
        self.init(url: url)
        self.httpMethod = tfnRequest.method.rawValue
        self.allHTTPHeaderFields = tfnRequest.headers
        
        if let body = tfnRequest.body { self.httpBody = body }
        else if let parameters = tfnRequest.parameters, !parameters.isEmpty {
            self.httpBody = try? URLEncoding.default.encode(self, with: parameters).httpBody
        }
    }
}