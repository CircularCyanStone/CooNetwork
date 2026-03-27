//
//  NtkLogger.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation
import os.log

/// 全局日志实例
public let logger = NtkLogger.shared

/// 网络组件统一日志工具
/// 基于OSLog实现
public struct NtkLogger: Sendable {

    /// 全局共享实例
    public static let shared = NtkLogger()

    /// 日志子系统标识
    private let subsystem = "com.coo.network.CNtk"

    /// 全局日志开关（动态读取 NtkConfiguration）
    var isLoggingEnabled: Bool {
        NtkConfiguration.current.builder.isLoggingEnabled
    }

    /// 当前允许输出的最低日志等级
    let currentLevel: Level

    /// 初始化日志工具
    /// - Parameter currentLevel: 当前日志等级，默认为 .info。小于此等级的日志将不会输出
    init(currentLevel: Level = .info) {
        self.currentLevel = currentLevel
    }
    
    /// 日志类别
    public enum Category: String, Sendable {
        case deduplication = "Deduplication"
        case retry = "Retry"
        case cache = "Cache"
        case network = "Network"
        case interceptor = "Interceptor"
        case general = "General"
    }
    
    /// 日志级别
    public enum Level: Int, Sendable, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case fault = 4

        /// 比较日志级别优先级
        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        /// 转换为OSLogType
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .fault:
                return .fault
            }
        }
    }
    
    /// 输出日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    ///   - category: 日志类别
    ///   - file: 调用文件名
    ///   - function: 调用函数名
    ///   - line: 调用行号
    func log(
        _ message: String,
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // 检查全局开关
        guard isLoggingEnabled else { return }
        
        // 检查日志等级
        if level < currentLevel {
            return
        }
        
        // 提取文件名
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(function):\(line)"

        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        let logMessage = "[\(location)] \(message)"
        os_log("%{public}@", log: log, type: level.osLogType, logMessage)
    }
    
    /// 便捷方法：输出debug日志
    public func debug(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// 便捷方法：输出info日志
    public func info(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// 便捷方法：输出warning日志
    public func warning(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// 便捷方法：输出error日志
    public func error(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    /// 便捷方法：输出fault日志
    public func fault(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
}
