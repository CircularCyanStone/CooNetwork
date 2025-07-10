//
//  RequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

protocol NtkRequestHandler: Sendable {
    func handle(context: NtkRequestContext) async throws -> any iNtkResponse
}
