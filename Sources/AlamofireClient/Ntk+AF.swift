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

/// Alamofire 便捷类型别名。
///
/// 使用指引：
/// - ``NtkAF<T>`` — 等同于 `Ntk<T>`，用于声明 AF 后端的网络请求变量。
///   创建实例时使用 `NtkAF<T>.withAF(request)` 便捷方法，自动注入 AF 客户端和默认验证器。
/// - ``NtkAFBool`` — 等同于 `Ntk<Bool>`，用于只需判断成功/失败的请求。
/// - 当不需要耦合 Alamofire 时（如测试或使用其他后端），直接使用核心层的 `Ntk<T>`。
public typealias NtkAF<ResponseData> = Ntk<ResponseData>

/// Bool 响应的 AF 便捷别名，用于只需判断成功/失败的请求。
public typealias NtkAFBool = Ntk<Bool>

/// AF网络请求管理器扩展
/// 提供AF请求的便捷创建和配置功能，集成了默认的拦截器和UI交互闭包
public extension Ntk {

    /// 创建AF网络请求（使用默认 AFResponseMapKeys）
    /// 自动配置AF客户端
    /// - Parameters:
    ///   - request: AF请求对象
    ///   - validation: 验证对象
    ///   - responseParser: 响应解析器，默认为 NtkDataParsingInterceptor
    ///   - cacheStorage: 缓存存储策略，默认为 nil（不缓存）
    /// - Returns: 配置好的网络请求管理器
    nonisolated
    static func withAF(
        _ request: iAFRequest,
        validation: iNtkResponseValidation? = nil,
        responseParser: iNtkResponseParser? = nil,
        storage: iNtkCacheStorage? = nil
    ) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        return Ntk.withAF(request, keys: AFResponseMapKeys.self, validation: validation, responseParser: responseParser, storage: storage)
    }

    /// 创建AF网络请求（使用自定义 Keys 映射）
    /// - Parameters:
    ///   - request: AF请求对象
    ///   - keys: 响应字段映射类型
    ///   - responseParser: 响应解析器
    ///   - cacheStorage: 缓存存储策略
    /// - Returns: 配置好的网络请求管理器
    nonisolated
    static func withAF<Keys: iNtkResponseMapKeys>(
        _ request: iAFRequest,
        keys: Keys.Type,
        validation: iNtkResponseValidation? = nil,
        responseParser: iNtkResponseParser? = nil,
        storage: iNtkCacheStorage? = nil
    ) -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        let client = AFClient()
        var _validation = validation
        if _validation == nil {
            _validation = (request as? iNtkResponseValidation) ?? AFDefaultResponseValidation()
        }
        var _responseParser = responseParser
        if _responseParser == nil {
            _responseParser = NtkDataParsingInterceptor<ResponseData, Keys>(validation: _validation!)
        }
        let net = with(client, request: request, responseParser: _responseParser!, cacheStorage: storage)
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
