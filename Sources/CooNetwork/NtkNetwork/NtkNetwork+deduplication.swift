//
//  NtkNetwork+deduplication.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/3/20.
//

import Foundation

extension NtkNetwork {

    /// 禁用去重
    /// Upload 请求需要在拦截器链执行前禁用去重
    public func disableDeduplication() {
        lock.withLock {
            mutableRequest.disableDeduplication()
        }
    }
}
