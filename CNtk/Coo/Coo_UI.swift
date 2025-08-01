//
//  Coo_UI.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//
// 按需封装：
// OC版本适配时，具体类直接构建一个请求的执行类在里面使用Swift方法，并转换成OC可用的方法。
// 这样子可以避免将更多的类转换成OC版本，只需要最终被调用请求方法支持OC和返回值模型支持OC就可以了。
// 成本最小.
import Foundation
import SVProgressHUD
import NtkNetwork

extension Coo {
 
    /// 构建loading的拦截器
    /// - Parameter request: 请求
    /// - Returns: 拦截器实例
    static func getLoadingInterceptor(_ request: iRpcRequest) -> NtkLoadingInterceptor? {
        let interceptor = NtkLoadingInterceptor { request in
            Task { @MainActor in
                // TODO: 替换为项目中使用的Loading组件
                print("Loading started for request: \(request)")
                SVProgressHUD.show()
            }
        } interceptAfter: {_, _,_   in
            Task { @MainActor in
                // TODO: 替换为项目中使用的Loading组件
                print("Loading finished")
                SVProgressHUD.dismiss()
            }
        }
        return interceptor
    }
}
