//
//  Ntk+AF.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif
import Alamofire

/// 类型别名，便捷用于后端返回值JSON key的映射模式为AFResponseMapKeys。
public typealias NtkAF<ResponseData> = Ntk<ResponseData, AFResponseMapKeys>

/// 类型别名，用于返回值为Bool类型的情况，后端JSON key的映射模式为AFResponseMapKeys。
public typealias NtkAFBool = Ntk<Bool, AFResponseMapKeys>

/// AF网络请求管理器扩展
/// 提供AF请求的便捷创建和配置功能，集成了默认的拦截器和UI交互闭包
public extension Ntk {
    
    /// 创建AF网络请求
    /// 自动配置AF客户端
    /// - Parameters:
    ///   - request: AF请求对象
    ///   - dataParsingInterceptor: 响应解析器，默认为 AFDataParsingInterceptor
    ///   - validation: 响应校验器，默认为 nil (使用默认校验逻辑)
    ///   - cacheStorage: 缓存存储策略，默认为不缓存 (AFNoCacheStorage)
    /// - Returns: 配置好的网络请求管理器
    nonisolated
    static func withAF(
        _ request: iAFRequest,
        dataParsingInterceptor: iNtkInterceptor = AFDataParsingInterceptor<ResponseData, Keys>(),
        validation: iNtkResponseValidation = AFDetaultResponseValidation(),
        storage: iNtkCacheStorage = AFNoCacheStorage()
    ) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        // 创建 AFClient，注入缓存策略
        let client = AFClient<Keys>(storage: storage)
        let net = with(client, request: request, dataParsingInterceptor: dataParsingInterceptor, validation: validation)
        // Upload 请求自动禁用去重（uploadSource 不参与哈希计算，会导致误判重复）
        // 必须在拦截器链执行前设置，所以放在这里而非 AFClient.sendRequest() 中
        if request is iAFUploadRequest {
            net.disableDeduplication()
        }
        return net
    }
}

/// AF请求默认的响应体验证工具
/// 默认 code == 0 或 "0" 视为成功
public struct AFDetaultResponseValidation: iNtkResponseValidation {
    /// 初始化默认响应验证器
    public init() {}

    /// 验证服务端响应是否成功
    /// - Parameter response: 响应对象
    /// - Returns: code 为 0 或 "0" 时返回 true
    public func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        if let code = response.code.int, code == 0 {
            return true
        }
        if response.code.stringValue == "0" {
            return true
        }
        return false
    }
}
