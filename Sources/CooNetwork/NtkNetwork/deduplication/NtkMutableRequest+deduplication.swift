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
    private static let responseTypeKey = "ntk_response_type"

    /// 响应类型（用于去重隔离）
    /// 解决泛型擦除问题，确保不同返回类型的请求能够生成不同的去重键
    var responseType: String? {
        get {
            return extraData[Self.responseTypeKey] as? String
        }
        set {
            extraData[Self.responseTypeKey] = newValue
        }
    }

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
