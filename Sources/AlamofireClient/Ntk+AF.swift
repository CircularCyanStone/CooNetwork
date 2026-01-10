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
    /// 自动配置AF客户端、Loading拦截器和Toast拦截器
    /// - Parameters:
    ///   - request: AF请求对象
    ///   - validation: 响应校验器，默认为 nil (使用默认校验逻辑)
    ///   - loadingHandler: Loading 显示/隐藏回调，如果为 nil 则不显示 Loading
    ///   - toastHandler: Toast 显示回调，如果为 nil 则不显示 Toast
    /// - Returns: 配置好的网络请求管理器
    static func withAF(
        _ request: iAFRequest,
        validation: iNtkResponseValidation? = nil,
        loadingHandler: (@Sendable (Bool, String?) -> Void)? = nil,
        toastHandler: (@Sendable (String) -> Void)? = nil
    ) async -> NtkNetwork<ResponseData> where ResponseData: Decodable {
        // 创建无缓存的 AFClient
        let client = AFClient<Keys>()
        
        // 使用传入的 validation 或默认的 AFDetaultResponseValidation
        let responseValidation = validation ?? AFDetaultResponseValidation()
        
        var net = with(client, request: request, dataParsingInterceptor: AFDataParsingInterceptor<ResponseData, Keys>(), validation: responseValidation)
        
        // 添加 Loading 拦截器
        if let loadingHandler = loadingHandler {
            net = net.addInterceptor(getLoadingInterceptor(handler: loadingHandler))
        }
        
        // 添加 Toast 拦截器
        if let toastHandler = toastHandler {
            let toastInterceptor = AFToastInterceptor(toastHandler: toastHandler)
            net = net.addInterceptor(toastInterceptor)
        }
        
        return net
    }
}

// MARK: - Helper

extension Ntk {
    
    /// 构建基于计数的loading拦截器
    /// - Parameter handler: Loading 状态回调 (isLoading, text)
    /// - Returns: 基于计数的拦截器实例
    private static func getLoadingInterceptor(handler: @escaping @Sendable (Bool, String?) -> Void) -> NtkLoadingInterceptor {
        let interceptor = NtkLoadingInterceptor { request, loadingText  in
            // 请求前显示 Loading
            handler(true, loadingText)
        } interceptAfter: { request, response, error in
            // 请求后隐藏 Loading
            handler(false, nil)
        }
        return interceptor
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
