//
//  NtkLoadingInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation
import SVProgressHUD

/// 拦截器便捷的构造实现
struct NtkConvenientInterceptor: iNtkInterceptor, Sendable {
    
    var interceptBefore: (@Sendable (_ request: iNtkRequest) -> Void)?
    
    var interceptAfter: (@Sendable (_ request: iNtkRequest, _ response: any iNtkResponse) -> Void)?
    
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let showLoading = context.client.requestWrapper.showLoading
        let request = context.client.requestWrapper.request!
        
        let interceptBefore = interceptBefore
        let interceptAfter = interceptAfter
        
        if showLoading {
            Task { @MainActor in
                interceptBefore?(request)
            }
        }
        
        let response = try await next.handle(context: context)
        if showLoading {
            Task { @MainActor in
                interceptAfter?(request, response)
            }
        }
        return response
    }
}
