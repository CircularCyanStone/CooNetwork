//
//  Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation
import SVProgressHUD

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
    
    
    /// 构建loading的拦截器
    /// - Parameter request: 请求
    /// - Returns: 拦截器实例
    static func getLoadingInterceptor(_ request: RpcRequest) -> NtkLoadingInterceptor? {
        let showLoading = request.showLoading
        guard showLoading else {
            return nil
        }
        let interceptor = NtkLoadingInterceptor {
            SVProgressHUD.show()
        } interceptAfter: {
            SVProgressHUD.dismiss()
        }
        return interceptor
    }
}

func withRpc<ResponseData>(_ request: RpcRequest) -> NtkNetwork<ResponseData> {
    let client = RpcClient<RpcResponseMapKeys>()
    let net = NtkNetwork<ResponseData>(client)
        .with(request)
    return net
}
