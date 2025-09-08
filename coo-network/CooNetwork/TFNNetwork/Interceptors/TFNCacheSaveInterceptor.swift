import Foundation
import Alamofire

/// 数据提取器闭包类型，用于从不同类型的响应中提取数据
typealias DataExtractor = (any iTFNResponse) -> Data?

/// TFN缓存拦截器
struct TFNCacheSaveInterceptor: iTFNInterceptor {
    /// 缓存拦截器使用低优先级，在大部分处理完成后执行缓存操作
    var priority: TFNInterceptorPriority { .low }
    
    /// 数据提取器，用于从响应中提取需要缓存的数据
    private let dataExtractor: DataExtractor
    
    /// 默认初始化方法，使用默认的数据提取器
    init() {
        self.dataExtractor = Self.defaultDataExtractor
    }
    
    /// 自定义初始化方法，允许传入自定义的数据提取器
    /// - Parameter dataExtractor: 自定义的数据提取器闭包
    init(dataExtractor: @escaping DataExtractor) {
        self.dataExtractor = dataExtractor
    }
    
    /// 默认的数据提取器实现，保持原有的AFDataResponse<Data>类型转换逻辑
    /// - Parameter response: 响应对象
    /// - Returns: 提取的数据，如果无法提取则返回nil
    private static func defaultDataExtractor(_ response: any iTFNResponse) -> Data? {
        if let afResponse = response.response as? AFDataResponse<Data> {
            return afResponse.data
        }
        return nil
    }
    
    func intercept(_ context: TFNInterceptorContext, next: TFNNextHandler) async throws -> any iTFNResponse {
        let response = try await next.proceed(context)
        if !response.isCache {
            if let cachePolicy = context.mutableRequest.cachePolicy, cachePolicy.duration > 0, cachePolicy.shouldCache(context.mutableRequest) {
                if let data = dataExtractor(response) {
                    let cacheResult = await context.client.saveCache(context.mutableRequest, response: data)
                    print("TFN请求缓存\(cacheResult ? "成功" : "失败") \(context.mutableRequest.originalRequest)")
                }
            }
        }
        return response
    }
}
