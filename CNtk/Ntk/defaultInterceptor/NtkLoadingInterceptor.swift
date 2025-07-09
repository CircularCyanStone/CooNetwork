//
//  NtkLoadingInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation
import SVProgressHUD

struct NtkLoadingInterceptor: iNtkInterceptor {
    
    @MainActor
    let interceptBefore: () -> Void
    
    @MainActor
    let interceptAfter: () -> Void
    
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        await MainActor.run {
            interceptBefore()
        }
        let response = try await next.handle(context: context)
        await MainActor.run {
            interceptAfter()
        }
        return response
    }
}
