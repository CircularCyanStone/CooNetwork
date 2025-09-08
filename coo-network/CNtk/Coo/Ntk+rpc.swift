//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation
import NtkNetwork

/// 默认情况下通用的Keys: iNtkResponseMapKeys为RpcResponseMapKeys的Coo的
/// 类型别名
typealias NtkDefault<ResponseData> = Ntk<ResponseData, RpcResponseMapKeys>

typealias NtkBoolDefault = Ntk<Bool, RpcResponseMapKeys>

/// RPC网络请求管理器
/// 提供RPC请求的便捷创建和配置功能，集成了默认的拦截器和UI交互
///
/// 使用泛型类比泛型方法方便：业务场景里可以直接使用Coo<模型>，也可以在返回值里注明类型。
/// 两者皆可让编译器正常推导泛型类型。
/// 但是如果让with变成泛型方法，则只能通过对返回值注明类型，才能让编译器推导泛型类型。
/// 限定网络请求的逻辑都在@NtkActor隔离域内， 确保不会频繁的出现actor跳跃
extension Ntk {
    
    /// 创建RPC网络请求
    /// 自动配置RPC客户端、Loading拦截器和Toast拦截器
    /// - Parameter request: RPC请求对象
    /// - Returns: 配置好的网络请求管理器
    static func withRpc(_ request: iRpcRequest, validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async -> NtkNetwork<ResponseData> { 
        let client = RpcClient<Keys>()
        var net = with(client, request: request, dataParsingInterceptor: RpcResponseParsingInterceptor<ResponseData, Keys>(), validation: validation)
        // 添加loading拦截器
        net = net.addInterceptor(getLoadingInterceptor())
        net = net.addInterceptor(CooToastInterceptor())
        if request.requestConfiguration != nil {
            net = net.addInterceptor(NtkCacheSaveInterceptor())
        }
        return net
    }
    
    /// 构建基于计数的loading拦截器（推荐使用）
    /// 支持多个并发请求，解决Loading提前消失的问题
    /// 支持Swift6严格并发模式
    /// - Returns: 基于计数的拦截器实例
    static func getLoadingInterceptor() -> NtkLoadingInterceptor {
        let interceptor = NtkLoadingInterceptor { request, loadingText  in
            Task { @MainActor in
                if let text = loadingText {
                    LoadingManager.showLoading(with: text)
                } else {
                    LoadingManager.showLoading()
                }
#if DEBUG
                LoadingManager.printDebugInfo()
#endif
            }
        } interceptAfter: { request, response, error in
            Task { @MainActor in
                LoadingManager.hideLoading()
#if DEBUG
                LoadingManager.printDebugInfo()
#endif
            }
        }
        return interceptor
    }
}

extension NtkNetwork {
    
    /// 便捷发起RPC请求并加载缓存
    ///
    /// 此方法是对通用 startWithCache 方法的 RPC 特化封装，
    /// 使用默认的缓存存储配置，简化 RPC 请求的调用。
    ///
    /// - Returns: 异步序列，按完成顺序返回缓存和网络响应
    /// - Throws: 在网络请求或缓存加载过程中可能抛出的任何错误
    func startRpcWithCache() -> AsyncThrowingStream<NtkResponse<ResponseData>, Error> {
        return self.requestWithCache()
    }
}
