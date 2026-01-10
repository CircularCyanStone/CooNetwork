//
//  Ntk+AF.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
import CooNetwork
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
    ///   - validation: 响应校验器，默认为 nil (使用默认校验逻辑)
    ///   - cacheStorage: 缓存存储策略，默认为不缓存 (AFNoCacheStorage)
    /// - Returns: 配置好的网络请求管理器
    static func withAF(
        _ request: iAFRequest,
        validation: iNtkResponseValidation? = nil,
        cacheStorage: iNtkCacheStorage = AFNoCacheStorage()
    ) async -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        // 创建 AFClient，注入缓存策略
        let client = AFClient<Keys>(storage: cacheStorage)
        
        // 使用传入的 validation 或默认的 AFDetaultResponseValidation
        let responseValidation = validation ?? AFDetaultResponseValidation()
        
        let net = with(client, request: request, dataParsingInterceptor: AFDataParsingInterceptor<ResponseData, Keys>(), validation: responseValidation)
        
        return net
    }
}

/// AF请求默认的响应体验证工具
/// 默认 code == 0 或 "0" 视为成功
public struct AFDetaultResponseValidation: iNtkResponseValidation {
    public init() {}
    
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
