//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

// 创建一个使用默认RpcResponseMapKeys的类型别名
typealias DefaultCoo = Coo<RpcResponseMapKeys>

class Coo<Keys: NtkResponseMapKeys> {
    static func with<ResponseData>(_ request: iRpcRequest) async -> NtkNetwork<ResponseData> {
        let client = RpcClient<Keys>()
        var net = await NtkNetwork<ResponseData>.with(request, client: client)
        // 添加loading拦截器
        if let ntkLoadingInterceptor = getLoadingInterceptor(request) {
            // 默认显示loading
            net = await net.addInterceptor(ntkLoadingInterceptor).hud(true)
        }
        return net
    }
}

extension NtkNetwork {
    
    /// RPC便捷发起请求方法
    /// - Parameter validation: 响应验证工具
    func startRpc(_ validation: iNtkResponseValidation = RpcDetaultResponseValidation()) async throws -> NtkResponse<ResponseData> {
        return try await self.validation(validation).sendRequest()
    }
}
