//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

@objcMembers
public class Coo: NSObject {
    
    static func with<ResponseData>(_ request: iRpcRequest) async -> NtkNetwork<ResponseData> {
        let client = RpcClient<RpcResponseMapKeys>()
        let net = await NtkNetwork<ResponseData>.with(request, client: client)
        // 添加loading拦截器
        if let ntkLoadingInterceptor = getLoadingInterceptor(request) {
            await net.addInterceptor(ntkLoadingInterceptor)
        }        
        return net
    }
}
