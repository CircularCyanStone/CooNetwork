//
//  RequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

@NtkActor
protocol NtkRequestHandler {
    func handle(context: NtkRequestContext) async throws -> any iNtkResponse
}
