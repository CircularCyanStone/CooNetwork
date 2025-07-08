//
//  NtkDefaultApiRequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

class NtkDefaultApiRequestHandler<ResponseData: Sendable>: NtkRequestHandler {
    func handle(context: NtkRequestContext) async throws -> any iNtkResponse {
        let response: NtkResponse<ResponseData> = try await context.client.execute()
        return response
    }
}
