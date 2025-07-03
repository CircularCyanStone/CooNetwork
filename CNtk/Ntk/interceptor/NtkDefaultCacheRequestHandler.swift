//
//  NtkDefaultApiRequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

class NtkDefaultCacheRequestHandler<ResponseData: Codable>: NtkRequestHandler {
    func handle(context: NtkRequestContext) async throws -> any iNtkResponse {
        guard let storage = context.storage else {
            fatalError("获取缓存时context.storage为nil，请核对代码逻辑")
        }
        if let response: NtkResponse<ResponseData> = try await context.client.loadCache(storage) {
            return response
        }
        throw NtkError.Cache.noCache
    }
}
