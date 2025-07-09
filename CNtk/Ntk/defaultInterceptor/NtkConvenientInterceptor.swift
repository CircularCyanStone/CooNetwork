//
//  NtkLoadingInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation
import SVProgressHUD

/// 拦截器便捷的构造实现
struct NtkConvenientInterceptor: iNtkInterceptor {
    
    @MainActor
    let interceptBefore: (_ request: iNtkRequest) -> Void
    
    @MainActor
    let interceptAfter: (_ request: iNtkRequest, _ response: any iNtkResponse) -> Void
    
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let request = context.client.request!
        await MainActor.run {
            interceptBefore(request)
        }
        let response = try await next.handle(context: context)
        await MainActor.run {
            interceptAfter(request, response)
        }
        return response
    }
}
