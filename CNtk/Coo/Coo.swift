//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

/// 使用默认RpcResponseMapKeys的Coo类型别名
typealias DefaultCoo = Coo<RpcResponseMapKeys>

/// RPC网络请求管理器
/// 提供RPC请求的便捷创建和配置功能，集成了默认的拦截器和UI交互
class Coo<Keys: NtkResponseMapKeys> {
    /// 创建RPC网络请求
    /// 自动配置RPC客户端、Loading拦截器和Toast拦截器
    /// - Parameter request: RPC请求对象
    /// - Returns: 配置好的网络请求管理器
    static func with<ResponseData>(_ request: iRpcRequest) async -> NtkNetwork<ResponseData> {
        let client = RpcClient<Keys>()
        var net = await NtkNetwork<ResponseData>.with(request, client: client)
        // 添加loading拦截器
        if let ntkLoadingInterceptor = getLoadingInterceptor(request) {
            // 默认显示loading
            net = await net.addInterceptor(ntkLoadingInterceptor).hud(true)
        }
        net = await net.addInterceptor(CooToastInterceptor())
        net = await net.addInterceptor(NtkDefaultCacheInterceptor())
        return net
    }
}

extension NtkNetwork {
    
    /// RPC便捷发起请求方法
    /// 使用默认的RPC响应验证器发起网络请求
    /// - Parameter validation: 响应验证器，默认使用RpcDetaultResponseValidation
    /// - Returns: 网络响应对象
    /// - Throws: 网络请求过程中的错误
    func startRpc(_ validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async throws -> NtkResponse<ResponseData> {
        return try await self.validation(validation).sendRequest()
    }
    
    func loadRpcCache(_ validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async throws -> NtkResponse<ResponseData>? {
        return try await self.validation(validation).loadCache()
    }
}
