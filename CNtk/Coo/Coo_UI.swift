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
    
    /// 构建基于计数的loading拦截器（推荐使用）
    /// 支持多个并发请求，解决Loading提前消失的问题
    /// 支持Swift6严格并发模式
    /// - Returns: 基于计数的拦截器实例
    static func getLoadingInterceptor() -> NtkLoadingInterceptor {
        let interceptor = NtkLoadingInterceptor { request, loadingText  in
            Task { @MainActor in
                if let text = loadingText {
                    LoadingManager.showLoading(with: text)
                } else {
                    LoadingManager.showLoading()
                }
#if DEBUG
                LoadingManager.printDebugInfo()
#endif
            }
        } interceptAfter: { request, response, error in
            Task { @MainActor in
                LoadingManager.hideLoading()
#if DEBUG
                LoadingManager.printDebugInfo()
#endif
            }
        }
        return interceptor
    }
}
