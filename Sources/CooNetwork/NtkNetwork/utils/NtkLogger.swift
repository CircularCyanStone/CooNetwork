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

    internal struct LogRecord: Sendable, Equatable {
        let level: Level
        let category: Category
        let message: String
    }

    /// 全局共享实例
    public static let shared = NtkLogger()

    /// 日志子系统标识
    private let subsystem = "com.coo.network.CNtk"

    /// 全局日志开关（动态读取 NtkConfiguration）
    var isLoggingEnabled: Bool {
        NtkConfiguration.current.builder.isLoggingEnabled
    }

    private var minimumLevel: Level {
        isLoggingEnabled ? .debug : .warning
    }

    @TaskLocal private static var testSink: (@Sendable (LogRecord) -> Void)?

    internal static func withTestSink<Result: Sendable>(
        _ sink: @escaping @Sendable (LogRecord) -> Void,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await $testSink.withValue(sink, operation: operation)
    }
    
    /// 日志类别
    public enum Category: String, Sendable {
        case deduplication = "Deduplication"
        case requestIdentity = "RequestIdentity"
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
        guard level >= minimumLevel else { return }

        NtkLogger.testSink?(LogRecord(level: level, category: category, message: message))
        
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
