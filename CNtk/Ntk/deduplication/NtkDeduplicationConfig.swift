//
//  NtkDeduplicationConfig.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求去重全局配置
/// 提供去重功能的全局配置选项
@NtkActor
class NtkDeduplicationConfig {
    
    /// 单例实例
    static let shared = NtkDeduplicationConfig()
    
    /// 是否全局启用去重功能
    /// 默认启用，可以通过此配置全局关闭去重功能
    var isGloballyEnabled: Bool = true
    

    
    /// 动态Header黑名单
    /// 这些Header在生成请求标识符时会被忽略
    var dynamicHeaderBlacklist: Set<String> = [
        "timestamp",
        "nonce",
        "request-id",
        "trace-id",
        "x-request-time",
        "x-trace-id",
        "authorization" // 可能包含动态token
    ]
    
    /// 私有初始化方法
    private init() {}
    
    /// 添加动态Header到黑名单
    /// - Parameter headerKey: Header键名
    func addDynamicHeader(_ headerKey: String) {
        dynamicHeaderBlacklist.insert(headerKey.lowercased())
    }
    
    /// 从黑名单中移除Header
    /// - Parameter headerKey: Header键名
    func removeDynamicHeader(_ headerKey: String) {
        dynamicHeaderBlacklist.remove(headerKey.lowercased())
    }
    
    /// 检查Header是否在黑名单中
    /// - Parameter headerKey: Header键名
    /// - Returns: 是否在黑名单中
    func isDynamicHeader(_ headerKey: String) -> Bool {
        return dynamicHeaderBlacklist.contains(headerKey.lowercased())
    }
    
    /// 重置为默认配置
    func resetToDefault() {
        isGloballyEnabled = true
        dynamicHeaderBlacklist = [
            "timestamp",
            "nonce",
            "request-id",
            "trace-id",
            "x-request-time",
            "x-trace-id",
            "authorization"
        ]
    }
}

// 注意：NtkDeduplicationLogger已迁移到NtkLogger统一日志工具
    // 请使用 NtkLogger.debug/info/warning/error 方法，并指定category为.deduplication
