//
//  NtkDeduplicationInterceptor.swift
//  NtkNetwork
//
//  Created by 李奇奇 on 2025/9/2.
//

import Foundation

struct NtkDeduplicationInterceptor: iNtkInterceptor {

    var priority: NtkInterceptorPriority { .coreOuterHighest }

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await NtkTaskManager.shared.executeWithDeduplication(request: context.mutableRequest) {
            let response = try await next.handle(context: context)
            return response
        }
        return response
    }

}
