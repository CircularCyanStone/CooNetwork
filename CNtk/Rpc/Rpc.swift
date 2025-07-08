//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

class Rpc {
    static func with(_ request: RpcRequest) -> NtkNetwork {
        let client = RpcClient<RpcResponseMapKeys>()
        let net = NtkNetwork(client)
            .with(request)
        return net
    }
}

func withRpc(_ request: RpcRequest) -> NtkNetwork {
    let client = RpcClient<RpcResponseMapKeys>()
    let net = NtkNetwork(client)
        .with(request)
    return net
}
