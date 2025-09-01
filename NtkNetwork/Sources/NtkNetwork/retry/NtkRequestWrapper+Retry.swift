//
//  NtkRequestWrapper+Retry.swift
//  CooNetwork
//
//  Created by Trae Builder on 2025/1/15.
//

import Foundation

/// NtkMutableRequest 重试功能扩展
/// NtkMutableRequest 作为可变请求对象，仅提供重试相关的数据存储功能
/// 重试逻辑的实现应该在 NtkNetwork 层面处理
extension NtkMutableRequest {
    /// 重试配置键
    private static let retryPolicyKey = "retry_policy"
    
    /// 设置重试策略
    /// - Parameter retryPolicy: 重试策略
    /// - Returns: 返回自身以支持链式调用
    @discardableResult
    mutating func retry(_ retryPolicy: iNtkRetryPolicy) -> NtkMutableRequest {
        self[Self.retryPolicyKey] = retryPolicy
        return self
    }
    
    /// 获取重试策略
    /// - Returns: 重试策略，如果未设置则返回nil
    var retryPolicy: iNtkRetryPolicy? {
        return self[Self.retryPolicyKey] as? iNtkRetryPolicy
    }
}
