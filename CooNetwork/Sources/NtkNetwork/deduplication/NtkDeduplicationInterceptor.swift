//
//  NtkDeduplicationInterceptor.swift
//  NtkNetwork
//
//  Created by 李奇奇 on 2025/9/2.
//

import Foundation

struct NtkDeduplicationInterceptor: iNtkInterceptor {
    
    func intercept(context: NtkInterceptorContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let taskManager = NtkTaskManager()
        let response = try await taskManager.executeWithDeduplication(request: context.mutableRequest) {
            let response = try await next.handle(context: context)
            return response
        }
        return response
    }
    
}
