//
//  NtkDefaultApiRequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

struct NtkDefaultApiRequestHandler<ResponseData: Sendable>: NtkRequestHandler {
    func handle(context: NtkRequestContext) async throws -> any iNtkResponse {
        let response: Sendable = try await context.client.execute()
        let handledResponse: NtkResponse<ResponseData> = try await context.client.handleResponse(response)
        return handledResponse
    }
}
