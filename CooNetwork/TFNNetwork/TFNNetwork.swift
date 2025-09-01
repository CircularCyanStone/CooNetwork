import Foundation

/// TFN网络主类
@TFNActor
final class TFNNetwork<DataType: Sendable & Decodable> {
    
    /// 响应结果枚举，用于区分网络响应和缓存响应
    private enum ResponseResult {
        case network(TFNResponse<DataType>)
        case cache(TFNResponse<DataType>?)
    }
    
    private var client: any iTFNClient
    private var interceptors: [any iTFNInterceptor]
    private var dataParsingInterceptor: iTFNInterceptor?
    private var mutableRequest: TFNMutableRequest?

    init(client: any iTFNClient, interceptors: [any iTFNInterceptor] = []) {
        self.client = client
        self.interceptors = interceptors
    }
    
    /**
     添加拦截器，为了避免缓存执行不必要的拦截器，这里添加的拦截器仅对正常请求生效
     缓存仅支持在缓存方法里，添加临时的拦截器。
     */
    func addInterceptors(_ interceptors: [any iTFNInterceptor]) {
        self.interceptors += interceptors
    }
    
    /**
     添加拦截器，为了避免缓存执行不必要的拦截器，这里添加的拦截器仅对正常请求生效
     缓存仅支持在缓存方法里，添加临时的拦截器。
     */
    func addInterceptor(_ interceptor: any iTFNInterceptor) {
        interceptors.append(interceptor)
    }
    
    func addDataParsingInterceptor(_ interceptor: iTFNInterceptor) -> Self {
        dataParsingInterceptor = interceptor
        return self
    }
    
    func with(_ request: iTFNRequest) -> Self {
        self.mutableRequest = TFNMutableRequest(request)
        return self
    }

    func request(additionalInterceptors: [any iTFNInterceptor] = [], storage: iTFNCacheStorage?) async throws -> TFNResponse<DataType> {
        guard let mutableRequest else {
            fatalError("request can not be nil")
        }
        guard let dataParsingInterceptor else {
            fatalError("dataParsingInterceptor can not be nil")
        }
        if mutableRequest.cachePolicy != nil && storage == nil {
            fatalError("\(mutableRequest) The request result need to be cached, but the storage is nil")
        }
        client.storage = storage
        var allInterceptors = self.interceptors + additionalInterceptors
        allInterceptors.append(dataParsingInterceptor)
        let chain = TFNInterceptorChain(interceptors: allInterceptors) { context in
            try await self.client.execute(context.mutableRequest)
        }
        let context = TFNInterceptorContext(mutableRequest: mutableRequest, client: client, isCache: true)
        let response = try await chain.execute(context)
        guard let finalResponse = response as? TFNResponse<DataType> else {
            throw TFNError.responseTypeMismatch(response)
        }
        return finalResponse
    }
    
    func loadCache(additionalInterceptors: [any iTFNInterceptor] = [], storage: iTFNCacheStorage) async throws -> TFNResponse<DataType>? {
        guard let mutableRequest else {
            fatalError("request can not be nil")
        }
        guard let dataParsingInterceptor else {
            fatalError("dataParsingInterceptor can not be nil")
        }
        client.storage = storage
        var allInterceptors = additionalInterceptors
        allInterceptors.append(dataParsingInterceptor)
        let chain = TFNInterceptorChain(interceptors: allInterceptors) { context in
            let cache = try await self.client.loadCache(context.mutableRequest) 
            if cache != nil {
                return cache!
            }
            throw TFNError.cacheEmpty
        }
        do {
            let context = TFNInterceptorContext(mutableRequest: mutableRequest, client: client, isCache: false)
            let response = try await chain.execute(context)
            guard let finalResponse = response as? TFNResponse<DataType> else {
                throw TFNError.responseTypeMismatch(response)
            }
            return finalResponse
        } catch TFNError.cacheEmpty {
            return nil
        }catch {
            throw error
        }
    }
    
    /// 检查是否有缓存数据
    /// - Parameters:
    ///   - additionalInterceptors: 额外的拦截器，与request方法保持一致
    ///   - storage: 实际关联的存储工具
    /// - Returns: 如果存在缓存数据返回true，否则返回false
    func hasCacheData(additionalInterceptors: [any iTFNInterceptor] = [], storage: iTFNCacheStorage) async -> Bool {
        guard let mutableRequest else {
            fatalError("request can not be nil")
        }
        client.storage = storage
        do {
            // 使用与request方法相同的拦截器组合逻辑，确保缓存key一致性
            // 注意：这里不包含dataParsingInterceptor，因为它只影响响应解析，不影响请求参数和缓存key
            let allInterceptors = additionalInterceptors
            let chain = TFNInterceptorChain(interceptors: allInterceptors) { context in
                try await self.client.hasCacheData(context.mutableRequest)
            }
            let context = TFNInterceptorContext(mutableRequest: mutableRequest, client: client, isCache: true)
            let response = try await chain.execute(context) as? TFNResponse<Bool>
            return response?.data ?? false
        } catch {
            // 如果拦截器处理失败，返回false
            return false
        }
    }
    
    /// 便捷发起网络请求并加载缓存
    ///
    /// 此方法会同时发起网络请求和加载缓存，并通过异步序列返回结果。
    /// 设计原则是优先显示缓存，网络请求返回后再刷新数据，以优化用户体验。
    ///
    /// - Parameters:
    ///   - additionalInterceptors: 额外的拦截器，默认为空数组
    ///   - cacheInterceptors: 缓存的拦截器，默认为空数组
    ///   - storage: 缓存存储器
    ///
    /// - Returns: 异步抛出流，包含TFNResponse响应结果
    /// - Throws: 在网络请求或缓存加载过程中可能抛出的任何错误
    func requestWithCache(
        additionalInterceptors: [any iTFNInterceptor] = [],
        cacheInterceptors: [any iTFNInterceptor] = [],
        storage: iTFNCacheStorage
    ) -> AsyncThrowingStream<TFNResponse<DataType>, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var networkReturnedFirst = false
                    try await withThrowingTaskGroup(of: ResponseResult.self) { group in
                        // 并发加载缓存
                        group.addTask {
                            do {
                                return .cache(try await self.loadCache(additionalInterceptors: cacheInterceptors, storage: storage))
                            } catch {
                                print("requestWithCache 缓存加载失败，但不影响网络请求: \(error)")
                                return .cache(nil)
                            }
                        }
                        
                        // 并发发起网络请求
                        group.addTask {
                            return .network(try await self.request(additionalInterceptors: additionalInterceptors, storage: storage))
                        }
                        
                        // 按完成顺序处理结果
                        for try await result in group {
                            switch result {
                            case .network(let response):
                                networkReturnedFirst = true
                                continuation.yield(response)
                                // 网络请求成功后，可以取消其他任务并提前结束
                                group.cancelAll()
                                
                            case .cache(let response):
                                if !networkReturnedFirst, let response = response {
                                    continuation.yield(response)
                                }
                            }
                        }
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable termination in
                switch termination {
                case .cancelled:
                    // 只有在流被取消时才取消底层任务
                    // 这通常发生在业务层主动取消或者上层作用域被取消
                    print("AsyncStream 被取消，取消底层任务")
                    task.cancel()
                case .finished:
                    // 流正常结束或因错误结束，不需要取消任务
                    // 因为任务要么已经完成，要么已经在 catch 块中处理了错误
                    print("AsyncStream 正常结束，无需取消任务")
                @unknown default:
                    fatalError("unknown")
                }
            }
        }
    }

}
