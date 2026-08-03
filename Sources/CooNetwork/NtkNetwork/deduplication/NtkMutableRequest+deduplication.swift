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

    private static let deduplicationEnabledKey = "ntk_deduplication_enabled"

    /// 禁用去重
    /// - Returns: 返回自身，支持链式调用
    @discardableResult
    public mutating func disableDeduplication() -> NtkMutableRequest {
        extraData[Self.deduplicationEnabledKey] = false
        return self
    }

    /// 检查是否启用了去重
    /// - Returns: 是否启用去重
    var isDeduplicationEnabled: Bool {
        return (extraData[Self.deduplicationEnabledKey] as? Bool) ?? true
    }
}
