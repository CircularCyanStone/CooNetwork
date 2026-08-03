//
//  NtkDeduplicationInterceptor.swift
//  NtkNetwork
//
//  Created by 李奇奇 on 2025/9/2.
//

import Foundation

struct NtkDeduplicationInterceptor: iNtkInterceptor {

    var priority: NtkInterceptorPriority { .outerHighest }

    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        try await NtkTaskManager.shared.executeWithDeduplication(
            request: context.request,
            identity: context.deduplicationIdentity,
            effectiveTimeout: context.effectiveTimeout
        ) {
            try await next.handle(context: context)
        }
    }

}
