//
//  NtkRequestWrapper+Deduplication.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求级去重策略。
///
/// 默认 `.inherit` 使用全局配置；`.enabled` 和 `.disabled` 分别强制覆盖全局配置。
public enum NtkDeduplicationPolicy: Sendable {
    /// 使用全局去重配置。
    case inherit
    /// 强制启用本请求的去重。
    case enabled
    /// 强制禁用本请求的去重。
    case disabled
}

/// NtkMutableRequest 去重功能扩展
/// 为可变请求对象添加去重相关的数据存储功能
extension NtkMutableRequest {

    private static let deduplicationPolicyKey = "ntk_deduplication_policy"

    /// 启用去重。
    ///
    /// 此设置会覆盖全局去重开关。
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    public mutating func enableDeduplication() -> NtkMutableRequest {
        extraData[Self.deduplicationPolicyKey] = NtkDeduplicationPolicy.enabled
        return self
    }

    /// 禁用去重
    ///
    /// 此设置会覆盖全局去重开关。
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    public mutating func disableDeduplication() -> NtkMutableRequest {
        extraData[Self.deduplicationPolicyKey] = NtkDeduplicationPolicy.disabled
        return self
    }

    /// 当前请求的去重策略。
    ///
    /// 未显式配置时为 `.inherit`。
    var deduplicationPolicy: NtkDeduplicationPolicy {
        (extraData[Self.deduplicationPolicyKey] as? NtkDeduplicationPolicy) ?? .inherit
    }
}
