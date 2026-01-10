//
//  AFClient.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
import CooNetwork
@preconcurrency import Alamofire

// MARK: - 辅助类型

/// 原始数据编码器，用于直接发送Data类型的body数据
private struct RawDataEncoding: ParameterEncoding, Sendable {
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data
        return request
    }
}

/// AF 客户端请求执行实现
/// 负责执行基于Alamofire的网络请求，支持泛型响应键映射
/// 去除了缓存功能，Toast使用闭包回调
public class AFClient<Keys: iNtkResponseMapKeys>: iNtkClient {
    
    /// 缓存存储实现 (占位实现，不进行实际缓存)
    public var storage: any iNtkCacheStorage
    
    /// Alamofire Session
    private let session: Session
    
    /// 初始化
    /// - Parameter session: Alamofire Session，默认为 .default
    public init(session: Session = .default) {
        self.session = session
        self.storage = AFNoCacheStorage()
    }
    
    /// 执行网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    public func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        try await sendRequest(request)
    }
    
    /// 发送AF请求
    /// 使用Alamofire执行底层网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    /// - Note: 标记为 nonisolated 以规避在 Actor 中使用非 Sendable 类型 (Any) 的参数传递问题
    private func sendRequest(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        guard let mRequest = request.originalRequest as? iAFRequest else {
            fatalError("request must be iAFRequest")
        }
        
        // 构建完整URL
        let url = (request.baseURL?.absoluteString ?? "") + request.path
        let method = HTTPMethod(rawValue: request.method.rawValue.uppercased())
        let headers = HTTPHeaders(request.headers ?? [:])
        
        // 准备请求配置
        let finalRequestModifier = createRequestModifier(for: mRequest)
        
        // 检查任务取消
        try Task.checkCancellation()
        
        // 创建请求任务
        let requestTask: DataRequest
        
        if let parameters = request.parameters, !parameters.isEmpty {
            // 处理参数：直接转换为 [String: Any]? 供 Alamofire 使用
            // 使用 iAFRequest 指定的 encoding
            requestTask = session.request(
                url,
                method: method,
                parameters: parameters,
                encoding: mRequest.encoding,
                headers: headers,
                requestModifier: finalRequestModifier
            )
        } else {
            // 无参数请求
            requestTask = session.request(
                url,
                method: method,
                headers: headers,
                requestModifier: finalRequestModifier
            )
        }
        
        // 配置验证策略
        let configuredRequest = applyValidation(requestTask, request: mRequest)
        
        // 执行请求并序列化响应
        // 使用 serializingData().response 获取完整的响应对象（包含 Data, URLResponse, Error 等）
        // 这种方式既利用了 Swift Concurrency (async/await)，又保留了处理底层响应的自由度
        let response = await configuredRequest.serializingData().response
        
        switch response.result {
        case .success(let data):
            // 4. 直接传递原始 Data，避免重复序列化带来的性能损耗
            return NtkClientResponse(
                data: data,
                msg: nil,
                response: response,
                request: mRequest,
                isCache: false
            )
        case .failure(let error):
            // 5. 错误处理
            if let urlError = error.underlyingError as? URLError {
                 if urlError.code == .timedOut {
                     throw NtkError.requestTimeout
                 } else {
                     throw NtkError.other(urlError)
                 }
            } else {
                throw NtkError.other(error)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func createRequestModifier(for request: iAFRequest) -> Session.RequestModifier? {
        let timeoutInterval = request.timeout
        let userModifier = request.requestModifier
        
        return { urlRequest in
            urlRequest.timeoutInterval = timeoutInterval
            try? userModifier?(&urlRequest)
        }
    }
    
    private func applyValidation(_ request: DataRequest, request mRequest: iAFRequest) -> DataRequest {
        if let validation = mRequest.validation {
            return request.validate(validation)
        } else {
            return request.validate() // 默认验证 200...299
        }
    }
    
}

/// 内部使用的无缓存存储实现
fileprivate struct AFNoCacheStorage: iNtkCacheStorage {
    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        return false
    }
    
    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        return nil
    }
    
    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        return false
    }
}
