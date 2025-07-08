//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

class Rpc {
    static func with<ResponseData>(_ request: RpcRequest) -> NtkNetwork<ResponseData> {
        let client = RpcClient<RpcResponseMapKeys>()
        let net = NtkNetwork<ResponseData>(client)
            .with(request)
        return net
    }
}

func withRpc<ResponseData>(_ request: RpcRequest) -> NtkNetwork<ResponseData> {
    let client = RpcClient<RpcResponseMapKeys>()
    let net = NtkNetwork<ResponseData>(client)
        .with(request)
    return net
}
