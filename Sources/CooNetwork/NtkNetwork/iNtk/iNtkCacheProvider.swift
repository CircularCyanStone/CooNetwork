//
//  iNtkCacheProvider.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/03/22.
//

import Foundation

/// 缓存能力提供者协议
/// 拦截器可遵循此协议，使 executor 通过协议发现获取缓存读取能力
public protocol iNtkCacheProvider: Sendable {
    @NtkActor
    func loadCacheData(for request: NtkMutableRequest) async throws -> (any Sendable)?
    @NtkActor
    func hasCacheData(for request: NtkMutableRequest) async -> Bool
}
