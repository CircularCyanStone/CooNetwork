import Foundation

// MARK: - Basic Types

/// TFN HTTP方法枚举
enum TFNHTTPMethod: String, CaseIterable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
}

/// TFN错误枚举
enum TFNError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case requestTimeout
    case httpCodeInvalid(_ response: HTTPURLResponse?)
    case networkFailure(underlying: Error)
    case decodingFailure(underlying: Error)
    case responseTypeMismatch(_ response: any iTFNResponse)
    case businessError(_ code: TFNReturnCode, _ message: String?)
    case cacheEmpty
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .requestTimeout: return "Request timed out."
        case .httpCodeInvalid(let response): return "Invalid Response \(String(describing: response))"
        case .networkFailure(let error): return "Network request failed: \(error.localizedDescription)"
        case .decodingFailure(let error): return "Response decoding failed: \(error.localizedDescription)"
        case .responseTypeMismatch: return "Response type mismatch after interceptor chain."
        case .businessError(let code, let message): return "Business error: [\(code.stringValue)] \(message ?? "No message")"
        case .cacheEmpty: return "cache is nil"
        case .unknown: return "unknown error"
        }
    }
}
