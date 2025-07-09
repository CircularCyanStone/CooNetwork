//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

class Coo {
    static func with<ResponseData>(_ request: RpcRequest) -> NtkNetwork<ResponseData> {
        let client = RpcClient<RpcResponseMapKeys>()
        let net = NtkNetwork<ResponseData>.with(request, client: client)
        
        // 添加loading拦截器
        if let ntkLoadingInterceptor = getLoadingInterceptor(request) {
            net.addInterceptor(ntkLoadingInterceptor)
        }        
        return net
    }
}

func withRpc<ResponseData>(_ request: RpcRequest) -> NtkNetwork<ResponseData> {
    let client = RpcClient<RpcResponseMapKeys>()
    let net = NtkNetwork<ResponseData>(client)
        .with(request)
    return net
}
