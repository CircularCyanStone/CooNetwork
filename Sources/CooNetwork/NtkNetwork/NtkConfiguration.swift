//
//  NtkConfiguration.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2026/1/6.
//
/**
 CooNetwork 全局配置

 配置应在应用启动时通过 configure() 设置
 */
import Foundation

public struct NtkConfiguration: Sendable {

    public struct Builder : Sendable{
        /// 日志开关（默认关闭）
        public var isLoggingEnabled: Bool = false

        /// 是否全局启用去重功能（默认启用）
        public var isDeduplicationEnabled: Bool = true

        /// 默认请求超时时间（秒）
        /// - Note: 所有请求的超时配置都以此值为基准
        public var defaultTimeout: TimeInterval = 20
    }

    /// 当前配置，带有默认值
    /// nonisolated(unsafe): 使用 lock 保护读写操作
    nonisolated(unsafe) private(set) static var current = NtkConfiguration()
    
    /// 添加Builder类型可以保证，internal private(set) 修饰，
    /// 可以保证外部无法直接通过builder属性修改配置。
    /// 外部只能通过configure函数去修改属性。
    internal private(set) var builder: Builder = Builder()
    
    private static let lock = NtkUnfairLock()

    /// 更新全局配置
    /// - Parameter configuration: 配置修改闭包，接收 current 的可变引用
    public static func configure(_ configuration: (inout Builder) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        configuration(&current.builder)
    }
}
