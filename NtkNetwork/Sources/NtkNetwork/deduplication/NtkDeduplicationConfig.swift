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
public class NtkDeduplicationConfig {
    
    /// 单例实例
    public static let shared = NtkDeduplicationConfig()
    
    /// 是否全局启用去重功能
    /// 默认启用，可以通过此配置全局关闭去重功能
    public var isGloballyEnabled: Bool = true
    
    /// 重置去重配置
    /// 清空所有配置状态，恢复到初始状态
    public func reset() {
        isGloballyEnabled = true
        // 清理其他可能的状态
    }
    
    /// 私有初始化方法
    private init() {}
}
