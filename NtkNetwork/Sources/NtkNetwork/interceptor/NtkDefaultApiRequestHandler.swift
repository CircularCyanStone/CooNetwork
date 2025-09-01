//
//  NtkDefaultApiRequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

struct NtkDefaultApiRequestHandler<ResponseData: Sendable>: NtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        let response = try await context.client.execute(context.mutableRequest)
        return response
    }
}
