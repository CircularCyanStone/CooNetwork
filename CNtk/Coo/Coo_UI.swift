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
    static func getLoadingInterceptor(_ request: iRpcRequest) -> NtkConvenientInterceptor? {
        let interceptor = NtkConvenientInterceptor { request in
            Task { @MainActor in
                SVProgressHUD.show()
            }
        } interceptAfter: {_, _  in
            Task { @MainActor in
                SVProgressHUD.dismiss()
            }
        }
        return interceptor
    }
}
