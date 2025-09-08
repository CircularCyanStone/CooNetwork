//
//  RequestHandler.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/20.
//

import Foundation

@NtkActor
public protocol NtkRequestHandler: Sendable {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse
}
