//
//  NtkLogger.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation
import os.log

/// 网络组件统一日志工具
/// 基于OSLog实现，兼容iOS 10+
@NtkActor
struct NtkLogger {
    
    /// 日志子系统标识
    private static let subsystem = "com.coo.network.CNtk"
    
    /// 日志类别
    enum Category: String {
        case deduplication = "Deduplication"
        case retry = "Retry"
        case cache = "Cache"
        case network = "Network"
        case interceptor = "Interceptor"
        case general = "General"
    }
    
    /// 日志级别
    enum Level {
        case debug
        case info
        case warning
        case error
        case fault
        
        /// 转换为OSLogType
        @available(iOS 10.0, *)
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
        
        /// 用于iOS 10以下版本的字符串表示
        var stringValue: String {
            switch self {
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO"
            case .warning:
                return "WARNING"
            case .error:
                return "ERROR"
            case .fault:
                return "FAULT"
            }
        }
    }
    
    /// 全局日志开关
    static var isLoggingEnabled: Bool = true
    
    /// 调试模式开关（影响debug级别日志）
    static var isDebugMode: Bool = false
    
    /// 输出日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    ///   - category: 日志类别
    ///   - file: 调用文件名
    ///   - function: 调用函数名
    ///   - line: 调用行号
    static func log(
        _ message: String,
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // 检查全局开关
        guard isLoggingEnabled else { return }
        
        // 检查debug级别日志
        if level == .debug && !isDebugMode {
            return
        }
        
        // 提取文件名
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(function):\(line)"
        
        if #available(iOS 10.0, *) {
            // iOS 10+ 使用OSLog
            let log = OSLog(subsystem: subsystem, category: category.rawValue)
            let logMessage = "[\(location)] \(message)"
            os_log("%{public}@", log: log, type: level.osLogType, logMessage)
        } else {
            // iOS 10以下使用print
            let timestamp = DateFormatter.logFormatter.string(from: Date())
            let logMessage = "[\(category.rawValue)][\(level.stringValue)][\(timestamp)][\(location)] \(message)"
            print(logMessage)
        }
    }
    
    /// 便捷方法：输出debug日志
    static func debug(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出info日志
    static func info(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出warning日志
    static func warning(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出error日志
    static func error(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出fault日志
    static func fault(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
}

/// DateFormatter扩展（用于iOS 10以下版本）
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
