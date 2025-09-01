import Foundation
import Alamofire

// MARK: - 辅助类型

/// 组合拦截器
/// 将重试策略和用户自定义拦截器组合在一起
private struct CombinedInterceptor: RequestInterceptor {
    let retryPolicy: RetryPolicy
    let userInterceptor: RequestInterceptor
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @Sendable @escaping (Result<URLRequest, Error>) -> Void) {
        // 先执行用户拦截器的适配
        userInterceptor.adapt(urlRequest, for: session) { result in
            completion(result)
        }
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @Sendable @escaping (RetryResult) -> Void) {
        // 先尝试重试策略
        retryPolicy.retry(request, for: session, dueTo: error) { retryResult in
            switch retryResult {
            case .retry, .retryWithDelay:
                // 如果重试策略决定重试，直接重试
                completion(retryResult)
            case .doNotRetry, .doNotRetryWithError:
                // 如果重试策略决定不重试，再询问用户拦截器
                userInterceptor.retry(request, for: session, dueTo: error, completion: completion)
            }
        }
    }
}

// MARK: - RawDataEncoding

/// 原始数据编码器，用于直接发送Data类型的body数据
/// 
/// 当请求需要发送原始的Data数据（如JSON、XML、二进制数据等）时使用此编码器
/// 它会将Data直接设置为HTTP请求的body，不进行任何额外的编码处理
private struct RawDataEncoding: ParameterEncoding, Sendable {
    /// 要发送的原始数据
    let data: Data
    
    /// 初始化原始数据编码器
    /// - Parameter data: 要编码的原始数据
    init(data: Data) {
        self.data = data
    }
    
    /// 将原始数据编码到URLRequest中
    /// - Parameters:
    ///   - urlRequest: 要编码的URL请求
    ///   - parameters: 参数（此编码器中忽略）
    /// - Returns: 编码后的URLRequest
    /// - Throws: 编码过程中的错误
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data
        return request
    }
}

// MARK: - TFNAlamofireClient

/// TFN网络框架的Alamofire客户端实现
/// 
/// 此客户端提供了对iTFNRequest和iAlamofireRequest的完整支持，
/// 包括基础网络请求功能和Alamofire的高级特性（如拦截器、验证、缓存等）
@TFNActor
struct TFNAlamofireClient: iTFNClient {
    
    // MARK: - Properties
    
    /// 缓存存储（可选）
    var storage: iTFNCacheStorage?
    
    /// Alamofire会话实例
    private let session: Session
    
    // MARK: - Initialization
    
    /// 初始化TFN Alamofire客户端
    /// - Parameter configuration: URL会话配置，默认使用.default配置
    init(configuration: URLSessionConfiguration = .default) {
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - iTFNClient Implementation
    
    /// 执行网络请求
    /// - Parameter request: 要执行的网络请求
    /// - Returns: 网络响应
    /// - Throws: 网络请求过程中的错误
    func execute(_ request: TFNMutableRequest) async throws -> any iTFNResponse {
        // 构建完整的请求URL
        let url = request.baseURL.appendingPathComponent(request.path)
        
        do {
#if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
#endif
            return try await withCheckedThrowingContinuation { continuation in
                // 创建Alamofire请求，根据请求类型选择配置方式
                let alamofireRequest = self.createAlamofireRequest(url: url, request: request)
                
                // 应用iAlamofireRequest的高级配置（如果适用）
                let configuredRequest = self.applyAlamofireConfiguration(alamofireRequest, request: request)
                
                // 配置响应处理
                print("""
                ===========================Network Start=================================
                地址：\(String(describing: url))
                ===========================Network=================================
                """)
                configuredRequest.responseData { afResponse in
                    
#if DEBUG
                let endTime = CFAbsoluteTimeGetCurrent()
                    let apiReponseTime = String(format: "\(String(describing: afResponse.request?.url))接口响应时长：%f 毫秒", (endTime - startTime) * 1000)
                if let urlRequest = afResponse.request, let body = urlRequest.httpBody {
                    let reqParam = String(data: body, encoding: String.Encoding.utf8) ?? ""
                    let reqParamArray = reqParam.components(separatedBy: "&")
                    
                    print("""
                    ===========================Network End=================================
                    \(apiReponseTime)
                    地址：\(String(describing: urlRequest))
                    参数：\(String(describing: reqParamArray))
                    请求头：\(urlRequest.allHTTPHeaderFields?.description ?? "")
                    ===========================Network=================================
                    """)
                }
#endif
                    
                    switch afResponse.result {
                    case .success(let data):
                        if let response = afResponse.response, response.statusCode == 200 {
                            // 创建成功响应
                            let response = TFNDataResponse(
                                data: data,
                                request: request,
                                response: afResponse,
                                isCache: false
                            )
                            continuation.resume(returning: response)
                        }else {
                            continuation.resume(throwing: TFNError.httpCodeInvalid(afResponse.response))
                        }
                        
                    case .failure(let afError):
                        // 映射Alamofire错误到TFN错误
                        continuation.resume(throwing: afError)
                    }
                }
            }
        } catch let error as AFError {
            throw self.mapError(error)
        } catch {
            throw error
        }
    }
}

// MARK: - Request Creation

extension TFNAlamofireClient {
    
    /// 创建Alamofire请求的入口方法
    /// 
    /// 根据请求类型（iTFNRequest或iAlamofireRequest）选择相应的创建策略
    /// - Parameters:
    ///   - url: 请求URL
    ///   - request: TFN请求对象
    /// - Returns: 配置好的Alamofire DataRequest
    private func createAlamofireRequest(url: URL, request: TFNMutableRequest) -> DataRequest {
        let httpMethod = HTTPMethod(rawValue: request.method.rawValue)
        let headers = HTTPHeaders(request.headers ?? [:])
        
        // 检查是否为iAlamofireRequest，使用其高级配置
        if let alamofireRequest = request.originalRequest as? any iAlamofireRequest {
            return createAdvancedRequest(url: url, request: alamofireRequest, httpMethod: httpMethod, headers: headers)
        } else {
            return createBasicRequest(url: url, request: request, httpMethod: httpMethod, headers: headers)
        }
    }
    
    /// 创建高级Alamofire请求（支持iAlamofireRequest的所有配置）
    /// 
    /// 此方法处理iAlamofireRequest的高级特性，包括：
    /// - 自定义编码方式
    /// - 拦截器支持（包括重试策略）
    /// - 请求修改器（包括超时设置）
    /// - Parameters:
    ///   - url: 请求URL
    ///   - request: iAlamofireRequest对象
    ///   - httpMethod: HTTP方法
    ///   - headers: HTTP头部
    /// - Returns: 配置好的DataRequest
    private func createAdvancedRequest(url: URL, request: any iAlamofireRequest, httpMethod: HTTPMethod, headers: HTTPHeaders) -> DataRequest {
        // 创建组合的requestModifier（包含超时设置和用户自定义修改器）
        let finalRequestModifier = createRequestModifier(for: request)
        
        // 创建组合的拦截器（包含重试策略和用户自定义拦截器）
        let finalInterceptor = createCombinedInterceptor(for: request)
        
        // 根据请求数据类型选择编码方式
        if let body = request.body {
            // 有body数据时，使用RawDataEncoding直接发送原始数据
            return session.request(
                url,
                method: httpMethod,
                parameters: nil,
                encoding: RawDataEncoding(data: body),
                headers: headers,
                interceptor: finalInterceptor,
                requestModifier: finalRequestModifier
            )
        } else if let parameters = request.parameters, !parameters.isEmpty {
            // 有parameters时，使用iAlamofireRequest指定的编码方式
            return session.request(
                url,
                method: httpMethod,
                parameters: parameters,
                encoding: request.encoding, // 使用协议指定的编码方式
                headers: headers,
                interceptor: finalInterceptor,
                requestModifier: finalRequestModifier
            )
        } else {
            // 无参数请求
            return session.request(
                url,
                method: httpMethod,
                headers: headers,
                interceptor: finalInterceptor,
                requestModifier: finalRequestModifier
            )
        }
    }
    
    /// 创建基础Alamofire请求（兼容普通iTFNRequest）
    /// 
    /// 此方法为普通的iTFNRequest提供基础的网络请求功能，包括：
    /// - 自动选择编码方式（GET使用URL编码，其他使用JSON编码）
    /// - 超时设置支持
    /// - 原始数据发送支持
    /// - Parameters:
    ///   - url: 请求URL
    ///   - request: iTFNRequest对象
    ///   - httpMethod: HTTP方法
    ///   - headers: HTTP头部
    /// - Returns: 配置好的DataRequest
    private func createBasicRequest(url: URL, request: any iTFNRequest, httpMethod: HTTPMethod, headers: HTTPHeaders) -> DataRequest {
        // 创建超时requestModifier
        let timeoutModifier = createTimeoutModifier(for: request)
        
        // 根据HTTP方法和参数类型配置请求
        if let body = request.body {
            // 如果有body数据，直接使用RawDataEncoding发送原始数据
            return session.request(
                url,
                method: httpMethod,
                parameters: nil,
                encoding: RawDataEncoding(data: body),
                headers: headers,
                requestModifier: timeoutModifier
            )
        } else if let parameters = request.parameters, !parameters.isEmpty {
            // 如果有parameters，根据HTTP方法选择编码方式
            // GET请求使用URL编码，其他请求使用JSON编码
            let encoding: ParameterEncoding = request.method == .get ? URLEncoding.default : JSONEncoding.default
            return session.request(
                url,
                method: httpMethod,
                parameters: parameters,
                encoding: encoding,
                headers: headers,
                requestModifier: timeoutModifier
            )
        } else {
            // 无参数请求
            return session.request(
                url,
                method: httpMethod,
                headers: headers,
                requestModifier: timeoutModifier
            )
        }
    }
}

// MARK: - Configuration

extension TFNAlamofireClient {
    
    /// 应用iAlamofireRequest的高级配置
    /// 
    /// 此方法处理iAlamofireRequest的高级特性配置，包括：
    /// - 重试策略
    /// - 响应验证规则
    /// - 缓存策略
    /// - Parameters:
    ///   - dataRequest: 要配置的DataRequest
    ///   - request: TFN请求对象
    /// - Returns: 配置后的DataRequest
    private func applyAlamofireConfiguration(_ dataRequest: DataRequest, request: any iTFNRequest) -> DataRequest {
        var configuredRequest = dataRequest
        
        // 如果是iAlamofireRequest，应用其高级配置
        if let alamofireRequest = request as? any iAlamofireRequest {
            
            // 注意：重试策略已通过createCombinedInterceptor方法在请求创建时应用
            
            // 应用验证规则
            if let validation = alamofireRequest.validation {
                configuredRequest = configuredRequest.validate(validation)
            } else {
                // 使用默认验证（验证状态码200-299）
                configuredRequest = configuredRequest.validate()
            }
            
            // 应用缓存策略
            if let cacheResponse = alamofireRequest.cacheResponse {
                configuredRequest = configuredRequest.cacheResponse(using: cacheResponse)
            }
        } else {
            // 普通iTFNRequest使用默认验证
            configuredRequest = configuredRequest.validate()
        }
        
        return configuredRequest
    }
}

// MARK: - Request Modifiers

extension TFNAlamofireClient {
    
    /// 为iAlamofireRequest创建组合的拦截器
    /// 
    /// 此方法将重试策略和用户自定义的拦截器组合成一个统一的拦截器
    /// - Parameter request: iAlamofireRequest对象
    /// - Returns: 组合后的拦截器，如果没有任何拦截器则返回nil
    private func createCombinedInterceptor(for request: any iAlamofireRequest) -> RequestInterceptor? {
        let retryPolicy = request.retryPolicy
        let userInterceptor = request.interceptor
        
        // 如果没有任何拦截器，返回nil
        guard retryPolicy != nil || userInterceptor != nil else {
            return nil
        }
        
        // 如果只有重试策略，直接返回
        if let retryPolicy = retryPolicy, userInterceptor == nil {
            return retryPolicy
        }
        
        // 如果只有用户拦截器，直接返回
        if let userInterceptor = userInterceptor, retryPolicy == nil {
            return userInterceptor
        }
        
        // 如果两者都有，创建组合拦截器
        if let retryPolicy = retryPolicy, let userInterceptor = userInterceptor {
            return CombinedInterceptor(retryPolicy: retryPolicy, userInterceptor: userInterceptor)
        }
        
        return nil
    }
    
    /// 为iAlamofireRequest创建组合的requestModifier
    /// 
    /// 此方法将超时设置和用户自定义的requestModifier组合成一个统一的修改器
    /// - Parameter request: iAlamofireRequest对象
    /// - Returns: 组合后的requestModifier，如果没有任何修改器则返回nil
    private func createRequestModifier(for request: any iAlamofireRequest) -> Session.RequestModifier? {
        let timeoutModifier = createTimeoutModifier(for: request)
        let userModifier = request.requestModifier
        
        // 如果没有任何修改器，返回nil
        guard timeoutModifier != nil || userModifier != nil else {
            return nil
        }
        
        // 组合超时修改器和用户自定义修改器
        return { urlRequest in
            try? timeoutModifier?(&urlRequest)
            try? userModifier?(&urlRequest)
        }
    }
    
    /// 创建超时requestModifier
    /// 
    /// 根据iTFNRequest的timeoutInterval属性创建超时设置修改器
    /// - Parameter request: iTFNRequest对象
    /// - Returns: 超时requestModifier，如果没有设置超时则返回nil
    private func createTimeoutModifier(for request: any iTFNRequest) -> Session.RequestModifier? {
        guard let timeoutInterval = request.timeoutInterval else {
            return nil
        }
        
        return { urlRequest in
            urlRequest.timeoutInterval = timeoutInterval
        }
    }
}

// MARK: - Error Handling

extension TFNAlamofireClient {
    
    /// 将Alamofire错误映射为TFN错误
    /// 
    /// 此方法将Alamofire的AFError转换为TFN框架的标准错误类型，
    /// 提供更好的错误处理和用户体验
    /// - Parameter error: Alamofire错误
    /// - Returns: 对应的TFN错误
    private func mapError(_ error: AFError) -> TFNError {
        // 检查是否为超时错误
        if let underlyingError = error.underlyingError as? URLError, underlyingError.code == .timedOut {
            return .requestTimeout
        }
        
        // 其他错误统一映射为网络失败错误
        return .networkFailure(underlying: error)
    }
}
