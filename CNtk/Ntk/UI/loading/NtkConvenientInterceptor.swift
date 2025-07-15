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
    
    var interceptAfter: (@Sendable (_ request: iNtkRequest, _ response: (any iNtkResponse)?, _ error: (any Error)?) -> Void)?
    
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let requestWrapper = context.client.requestWrapper
        let showLoading = requestWrapper.showLoading
        let request = requestWrapper.request!
        
        let interceptBefore = interceptBefore
        let interceptAfter = interceptAfter
        
        if showLoading {
            interceptBefore?(request)
        }
        
        do {
            let response = try await next.handle(context: context)
            if showLoading {
                interceptAfter?(request, response, nil)
            }
            return response
        } catch {
            if showLoading {
                interceptAfter?(request, nil, error)
            }
            throw error
        }
    }
}
