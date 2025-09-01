//
//  NtkFixedIntervalRetryPolicy.swift
//  CNtk
//
//  固定间隔重试策略实现
//

import Foundation

/// 固定间隔重试策略
/// 每次重试使用相同的延迟时间
public struct NtkFixedIntervalRetryPolicy: iNtkRetryPolicy {
    /// 最大重试次数
    public let maxRetryCount: Int
    
    /// 固定延迟时间（秒）
    public let interval: TimeInterval
    
    /// 随机抖动因子（0.0-1.0），用于避免惊群效应
    public let jitterFactor: Double
    
    /// 初始化固定间隔重试策略
    /// - Parameters:
    ///   - maxRetryCount: 最大重试次数，默认3次
    ///   - interval: 固定延迟时间，默认2秒
    ///   - jitterFactor: 随机抖动因子，默认0.1
    public init(
        maxRetryCount: Int = 3,
        interval: TimeInterval = 2.0,
        jitterFactor: Double = 0.1
    ) {
        self.maxRetryCount = maxRetryCount
        self.interval = interval
        self.jitterFactor = max(0.0, min(1.0, jitterFactor)) // 确保在0-1范围内
    }
    
    public func retryDelay(for attemptCount: Int, error: Error) -> TimeInterval? {
        guard shouldRetry(attemptCount: attemptCount, error: error) else {
            return nil
        }
        
        // 固定间隔
        var delay = interval
        
        // 添加随机抖动，避免惊群效应
        if jitterFactor > 0 {
            let jitter = interval * jitterFactor * Double.random(in: -1.0...1.0)
            delay = max(0, interval + jitter)
        }
        
        return delay
    }
}

// MARK: - 便利构造器
extension NtkFixedIntervalRetryPolicy {
    /// 快速重试策略：最多3次，间隔1秒
    public static var fast: NtkFixedIntervalRetryPolicy {
        return NtkFixedIntervalRetryPolicy(
            maxRetryCount: 3,
            interval: 1.0,
            jitterFactor: 0.1
        )
    }
    
    /// 标准重试策略：最多5次，间隔2秒
    public static var standard: NtkFixedIntervalRetryPolicy {
        return NtkFixedIntervalRetryPolicy(
            maxRetryCount: 5,
            interval: 2.0,
            jitterFactor: 0.2
        )
    }
    
    /// 慢速重试策略：最多7次，间隔5秒
    public static var slow: NtkFixedIntervalRetryPolicy {
        return NtkFixedIntervalRetryPolicy(
            maxRetryCount: 7,
            interval: 5.0,
            jitterFactor: 0.3
        )
    }
    
    /// 无抖动重试策略：精确的固定间隔
    public static func precise(maxRetryCount: Int = 3, interval: TimeInterval = 2.0) -> NtkFixedIntervalRetryPolicy {
        return NtkFixedIntervalRetryPolicy(
            maxRetryCount: maxRetryCount,
            interval: interval,
            jitterFactor: 0.0
        )
    }
}
