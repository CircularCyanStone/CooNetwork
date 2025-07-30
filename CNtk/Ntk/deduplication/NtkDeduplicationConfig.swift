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
    
    /// 是否启用调试日志
    /// 开启后会输出去重相关的调试信息
    var isDebugLoggingEnabled: Bool = false
    
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
        isDebugLoggingEnabled = false
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

/// 去重调试日志工具
@NtkActor
struct NtkDeduplicationLogger {
    
    /// 输出调试日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    static func log(_ message: String, level: LogLevel = .info) {
        guard NtkDeduplicationConfig.shared.isDebugLoggingEnabled else { return }
        
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("[NtkDeduplication][\(level.rawValue)][\(timestamp)] \(message)")
    }
    
    /// 日志级别
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}

/// DateFormatter扩展
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
