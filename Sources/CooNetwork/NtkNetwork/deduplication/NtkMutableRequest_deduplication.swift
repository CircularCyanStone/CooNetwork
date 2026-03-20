//
//  NtkRequestWrapper+Deduplication.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// NtkMutableRequest 去重功能扩展
/// 为可变请求对象添加去重相关的数据存储功能
extension NtkMutableRequest {

    /// 响应类型（用于去重隔离）
    /// 解决泛型擦除问题，确保不同返回类型的请求能够生成不同的去重键
    var responseType: String? {
        get {
            return extraData[NtkDeduplicationKeys.responseTypeKey] as? String
        }
        set {
            extraData[NtkDeduplicationKeys.responseTypeKey] = newValue
        }
    }

    /// 去重策略
    /// 控制请求是否启用去重功能
    var deduplicationPolicy: NtkDeduplicationPolicy? {
        get {
            return extraData[NtkDeduplicationKeys.deduplicationPolicyKey] as? NtkDeduplicationPolicy
        }
        set {
            extraData[NtkDeduplicationKeys.deduplicationPolicyKey] = newValue
        }
    }

    /// 启用去重
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    mutating func enableDeduplication() -> NtkMutableRequest {
        deduplicationPolicy = .enabled
        return self
    }

    /// 禁用去重
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    public mutating func disableDeduplication() -> NtkMutableRequest {
        deduplicationPolicy = .disabled
        return self
    }

    /// 检查是否启用了去重
    /// - Returns: 是否启用去重
    var isDeduplicationEnabled: Bool {
        return deduplicationPolicy?.isEnabled ?? true  // 默认启用
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
