import Foundation

/// 网络客户端协议，定义了执行网络请求的能力
@TFNActor
protocol iTFNClient: Sendable {
    
    var storage: iTFNCacheStorage? { get set }
    
    func execute(_ request: TFNMutableRequest) async throws -> any iTFNResponse
    
    /// 加载缓存数据
    /// - Returns: 缓存的响应数据，如果没有缓存则返回nil
    /// - Throws: 缓存加载过程中的错误
    func loadCache(_ request: TFNMutableRequest) async throws -> (any iTFNResponse)?
    
    func saveCache(_ request: TFNMutableRequest, response: Sendable) async -> Bool
    
    /// 检查是否有缓存数据
    /// - Returns: (any iTFNResponse).data 如果存在缓存数据返回true，否则返回false
    /// 此处设计返回值为(any iTFNResponse)，是为了统一设计，以确保所有的链路逻辑可以走统一的代码。
    /// 不管是加载缓存、判断缓存是否存在、发起请求，整体流程可以保持一致，只在拦截器的finalHandle有区别。
    func hasCacheData(_ request: TFNMutableRequest) async throws -> (any iTFNResponse)
}

extension iTFNClient {
    func loadCache(_ request: TFNMutableRequest) async throws -> (any iTFNResponse)? {
        storage?.addRequest(request)
        guard let storage else {
            fatalError("the storage is nil")
        }
        let util = TFNCacheManager(storage: storage)
        guard let cache: Data = await util.loadData(for: request) else {
            return nil
        }
        return TFNDataResponse(data: cache, request: request, response: cache, isCache: true)
    }
    
    func saveCache(_ request: TFNMutableRequest, response: any Sendable) async -> Bool {
        storage?.addRequest(request)
        guard let storage else {
            fatalError("the storage is nil")
        }
        let util = TFNCacheManager(storage: storage)
        return await util.storeData(response, for: request)
    }
    
    func hasCacheData(_ request: TFNMutableRequest) async -> (any iTFNResponse) {
        storage?.addRequest(request)
        guard let storage else {
            fatalError("the storage is nil")
        }
        let util = TFNCacheManager(storage: storage)
        let result = await util.hasValidCache(for: request)
        let response = TFNResponse<Bool>(code: .init(200), data: result, msg: nil, response: result, request: request)
        return response
    }
}
