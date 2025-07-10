//
//  Coo_UI.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation
import SVProgressHUD

extension Coo {
 
    /// 构建loading的拦截器
    /// - Parameter request: 请求
    /// - Returns: 拦截器实例
    static func getLoadingInterceptor(_ request: RpcRequest) -> NtkConvenientInterceptor? {
        let showLoading = request.showLoading
        guard showLoading else {
            return nil
        }
        let interceptor = NtkConvenientInterceptor {request in 
            SVProgressHUD.show()
        } interceptAfter: {_, _  in
            SVProgressHUD.dismiss()
        }
        return interceptor
    }
}
