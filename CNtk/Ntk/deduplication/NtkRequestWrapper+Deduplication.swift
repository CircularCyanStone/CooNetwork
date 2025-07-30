//
//  NtkRequestWrapper+Deduplication.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// NtkRequestWrapper 去重功能扩展
/// 为请求包装器添加去重相关的数据存储功能
extension NtkRequestWrapper {
    
    /// 去重策略存储键
    private static let deduplicationPolicyKey = "ntk_deduplication_policy"
    
    /// 去重策略
    /// 控制请求是否启用去重功能
    var deduplicationPolicy: NtkDeduplicationPolicy? {
        get {
            return extraData[Self.deduplicationPolicyKey] as? NtkDeduplicationPolicy
        }
        set {
            extraData[Self.deduplicationPolicyKey] = newValue
        }
    }
    
    /// 设置去重策略
    /// - Parameter policy: 去重策略
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    mutating func setDeduplicationPolicy(_ policy: NtkDeduplicationPolicy) -> NtkRequestWrapper {
        self.deduplicationPolicy = policy
        return self
    }
    
    /// 启用去重
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    mutating func enableDeduplication() -> NtkRequestWrapper {
        return setDeduplicationPolicy(.enabled)
    }
    
    /// 禁用去重
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    mutating func disableDeduplication() -> NtkRequestWrapper {
        return setDeduplicationPolicy(.disabled)
    }
    
    /// 检查是否启用了去重
    /// - Returns: 是否启用去重
    var isDeduplicationEnabled: Bool {
        return deduplicationPolicy?.isEnabled ?? true // 默认启用
    }
}

/// 请求去重策略
enum NtkDeduplicationPolicy {
    /// 启用去重
    case enabled
    /// 禁用去重
    case disabled
    
    /// 是否启用
    var isEnabled: Bool {
        switch self {
        case .enabled:
            return true
        case .disabled:
            return false
        }
    }
}