//
//  AFClient.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif
@preconcurrency import Alamofire

/// AF 客户端请求执行实现
/// 负责执行基于Alamofire的网络请求，支持泛型响应键映射
/// 去除了缓存功能，Toast使用闭包回调
public final class AFClient<Keys: iNtkResponseMapKeys>: iNtkClient {
    
    /// 缓存存储实现 (占位实现，不进行实际缓存)
    public let storage: any iNtkCacheStorage
    
    /// Alamofire Session
    private let session: Session
    
    /// 初始化
    /// - Parameters:
    ///   - session: Alamofire Session，默认为 .default
    ///   - storage: 缓存存储实现，默认为不缓存
    public init(session: Session = .default, storage: iNtkCacheStorage = AFNoCacheStorage()) {
        self.session = session
        self.storage = storage
    }
    
    /// 执行网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    @NtkActor
    public func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        try await sendRequest(request)
    }
    
    /// 发送AF请求
    /// 使用Alamofire执行底层网络请求
    /// - Returns: 服务端响应数据
    /// - Throws: 网络请求过程中的错误
    /// - Note: 标记为 nonisolated 以规避在 Actor 中使用非 Sendable 类型 (Any) 的参数传递问题
    @NtkActor
    private func sendRequest(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        guard let ntkRequest = request.originalRequest as? iAFRequest else {
            fatalError("request must be iAFRequest")
        }
        
        // 构建完整URL
        let url = (request.baseURL?.absoluteString ?? "") + request.path
        let method = HTTPMethod(rawValue: request.method.rawValue.uppercased())
        let headers = HTTPHeaders(request.headers ?? [:])
        
        // 准备请求配置
        let finalRequestModifier = createRequestModifier(for: ntkRequest)
        
        // 检查任务取消
        try Task.checkCancellation()
        
        // 创建请求任务
        var afRequest: DataRequest
        
        if let parameters = request.parameters, !parameters.isEmpty {
            // 处理参数：直接转换为 [String: Any]? 供 Alamofire 使用
            // 使用 iAFRequest 指定的 encoding
            afRequest = session.request(
                url,
                method: method,
                parameters: parameters,
                encoding: ntkRequest.encoding,
                headers: headers,
                requestModifier: finalRequestModifier
            )
        } else {
            // 无参数请求
            afRequest = session.request(
                url,
                method: method,
                headers: headers,
                requestModifier: finalRequestModifier
            )
        }
        
        afRequest = ntkRequest.chainConfigureAFRequest(for: afRequest)
        
        // 配置验证策略
        let configuredRequest = applyValidation(afRequest, request: ntkRequest)
        // 执行请求并序列化响应
        // 使用 iAFRequest 配置的序列化方式，支持自定义 emptyResponseCodes 等参数
        let serializationTask = ntkRequest.configureSerialization(for: configuredRequest)
        let response = await serializationTask.response
        
        switch response.result {
        case .success(let data):
            // 4. 直接传递原始 Data，避免重复序列化带来的性能损耗
            return NtkClientResponse(
                data: data,
                msg: nil,
                response: response,
                request: ntkRequest,
                isCache: false
            )
        case .failure(let error):
            // 5. 错误处理
            
            if let urlError = error.underlyingError as? URLError, urlError.code == .timedOut {
                throw NtkError.requestTimeout
            }
            let fixResponse = NtkResponse<Data?>(
                code: NtkReturnCode(response.response?.statusCode ?? 0),
                data: nil,
                msg: "",
                response: response,
                request: ntkRequest,
                isCache: false
            )
            throw NtkError.AF.afError(error, ntkRequest, fixResponse)
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
public struct AFNoCacheStorage: iNtkCacheStorage {
    /// 初始化无缓存存储
    public init() {}

    /// 不存储数据，始终返回 false
    @NtkActor
    public func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        return false
    }

    /// 不读取数据，始终返回 nil
    @NtkActor
    public func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        return nil
    }

    /// 不存在缓存，始终返回 false
    @NtkActor
    public func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        return false
    }
}
