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

let logger = NtkLogger.shared

struct NtkLogger: Sendable {
    
    /// 全局共享实例
    static let shared: NtkLogger = {
        let logEnable = NtkConfiguration.shared.isLoggingEnabled
        let logger = NtkLogger(isLoggingEnabled: logEnable)
        return logger
    }()
    
    /// 日志子系统标识
    private let subsystem = "com.coo.network.CNtk"
    
    /// 全局日志开关
    let isLoggingEnabled: Bool
    
    /// 当前允许输出的最低日志等级
    let currentLevel: Level
    
    /// 初始化日志工具
    /// - Parameters:
    ///   - isLoggingEnabled: 是否启用日志
    ///   - currentLevel: 当前日志等级，默认为 .info。小于此等级的日志将不会输出
    init(isLoggingEnabled: Bool = true, currentLevel: Level = .info) {
        self.isLoggingEnabled = isLoggingEnabled
        self.currentLevel = currentLevel
    }
    
    /// 日志类别
    enum Category: String, Sendable {
        case deduplication = "Deduplication"
        case retry = "Retry"
        case cache = "Cache"
        case network = "Network"
        case interceptor = "Interceptor"
        case general = "General"
    }
    
    /// 日志级别
    enum Level: Int, Sendable, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case fault = 4
        
        static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
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
        
        if #available(iOS 10.0, *) {
            // iOS 10+ 使用OSLog
            let log = OSLog(subsystem: subsystem, category: category.rawValue)
            let logMessage = "[\(location)] \(message)"
            os_log("%{public}@", log: log, type: level.osLogType, logMessage)
        } else {
            // iOS 10以下使用print
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let timestamp = formatter.string(from: Date())
            let logMessage = "[\(category.rawValue)][\(level.stringValue)][\(timestamp)][\(location)] \(message)"
            print(logMessage)
        }
    }
    
    /// 便捷方法：输出debug日志
    func debug(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出info日志
    func info(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出warning日志
    func warning(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出error日志
    func error(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// 便捷方法：输出fault日志
    func fault(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
}
