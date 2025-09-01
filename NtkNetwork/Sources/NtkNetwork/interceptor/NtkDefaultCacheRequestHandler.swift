//
//  NtkDefaultApiRequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

struct NtkDefaultCacheRequestHandler<ResponseData: Sendable>: NtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        if let response = try await context.client.loadCache(context.mutableRequest) {
            return response
        }
        throw NtkError.Cache.noCache
    }
}
