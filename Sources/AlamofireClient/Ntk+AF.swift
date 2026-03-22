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
public typealias NtkAF<ResponseData> = Ntk<ResponseData>

/// 类型别名，用于返回值为Bool类型的情况，后端JSON key的映射模式为AFResponseMapKeys。
public typealias NtkAFBool = Ntk<Bool>

/// AF网络请求管理器扩展
/// 提供AF请求的便捷创建和配置功能，集成了默认的拦截器和UI交互闭包
public extension Ntk {

    /// 创建AF网络请求（使用默认 AFResponseMapKeys）
    /// 自动配置AF客户端
    /// - Parameters:
    ///   - request: AF请求对象
    ///   - responseParser: 响应解析器，默认为 AFDataParsingInterceptor
    ///   - validation: 响应校验器，默认为 nil (使用默认校验逻辑)
    ///   - cacheStorage: 缓存存储策略，默认为 nil（不缓存）
    /// - Returns: 配置好的网络请求管理器
    nonisolated
    static func withAF(
        _ request: iAFRequest,
        responseParser: any iNtkResponseParser = AFDataParsingInterceptor<ResponseData, AFResponseMapKeys>(),
        validation: iNtkResponseValidation = AFDefaultResponseValidation(),
        storage: iNtkCacheStorage? = nil
    ) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        let client = AFClient()
        let net = with(client, request: request, responseParser: responseParser, validation: validation, cacheStorage: storage)
        if request is iAFUploadRequest {
            net.disableDeduplication()
        }
        return net
    }

    /// 创建AF网络请求（使用自定义 Keys 映射）
    /// - Parameters:
    ///   - request: AF请求对象
    ///   - keys: 响应字段映射类型
    ///   - responseParser: 响应解析器
    ///   - validation: 响应校验器
    ///   - cacheStorage: 缓存存储策略
    /// - Returns: 配置好的网络请求管理器
    nonisolated
    static func withAF<Keys: iNtkResponseMapKeys>(
        _ request: iAFRequest,
        keys: Keys.Type,
        responseParser: any iNtkResponseParser = AFDataParsingInterceptor<ResponseData, Keys>(),
        validation: iNtkResponseValidation = AFDefaultResponseValidation(),
        storage: iNtkCacheStorage? = nil
    ) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        let client = AFClient()
        let net = with(client, request: request, responseParser: responseParser, validation: validation, cacheStorage: storage)
        if request is iAFUploadRequest {
            net.disableDeduplication()
        }
        return net
    }
}

/// AF请求默认的响应体验证工具
/// 默认 code == 0 或 "0" 视为成功
public struct AFDefaultResponseValidation: iNtkResponseValidation {
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
