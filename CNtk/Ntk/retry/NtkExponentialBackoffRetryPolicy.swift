//
//  NtkExponentialBackoffRetryPolicy.swift
//  CNtk
//
//  指数退避重试策略实现
//

import Foundation

/// 指数退避重试策略
/// 每次重试的延迟时间按指数增长：baseDelay * (multiplier ^ (attemptCount - 1))
struct NtkExponentialBackoffRetryPolicy: iNtkRetryPolicy {
    /// 最大重试次数
    let maxRetryCount: Int
    
    /// 基础延迟时间（秒）
    let baseDelay: TimeInterval
    
    /// 指数倍数
    let multiplier: Double
    
    /// 最大延迟时间（秒），防止延迟时间过长
    let maxDelay: TimeInterval
    
    /// 随机抖动因子（0.0-1.0），用于避免惊群效应
    let jitterFactor: Double
    
    /// 初始化指数退避重试策略
    /// - Parameters:
    ///   - maxRetryCount: 最大重试次数，默认3次
    ///   - baseDelay: 基础延迟时间，默认1秒
    ///   - multiplier: 指数倍数，默认2.0
    ///   - maxDelay: 最大延迟时间，默认30秒
    ///   - jitterFactor: 随机抖动因子，默认0.1
    init(
        maxRetryCount: Int = 3,
        baseDelay: TimeInterval = 1.0,
        multiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        jitterFactor: Double = 0.1
    ) {
        self.maxRetryCount = maxRetryCount
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
        self.jitterFactor = max(0.0, min(1.0, jitterFactor)) // 确保在0-1范围内
    }
    
    func retryDelay(for attemptCount: Int, error: Error) -> TimeInterval? {
        guard shouldRetry(attemptCount: attemptCount, error: error) else {
            return nil
        }
        
        // 计算指数延迟：baseDelay * (multiplier ^ (attemptCount - 1))
        let exponentialDelay = baseDelay * pow(multiplier, Double(attemptCount - 1))
        
        // 限制最大延迟时间
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // 添加随机抖动，避免惊群效应
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1.0...1.0)
        let finalDelay = max(0, cappedDelay + jitter)
        
        return finalDelay
    }
}

// MARK: - 便利构造器
extension NtkExponentialBackoffRetryPolicy {
    /// 快速重试策略：最多3次，延迟较短
    static var fast: NtkExponentialBackoffRetryPolicy {
        return NtkExponentialBackoffRetryPolicy(
            maxRetryCount: 3,
            baseDelay: 0.5,
            multiplier: 2.0,
            maxDelay: 8.0,
            jitterFactor: 0.1
        )
    }
    
    /// 标准重试策略：最多5次，中等延迟
    static var standard: NtkExponentialBackoffRetryPolicy {
        return NtkExponentialBackoffRetryPolicy(
            maxRetryCount: 5,
            baseDelay: 1.0,
            multiplier: 2.0,
            maxDelay: 30.0,
            jitterFactor: 0.2
        )
    }
    
    /// 慢速重试策略：最多7次，延迟较长
    static var slow: NtkExponentialBackoffRetryPolicy {
        return NtkExponentialBackoffRetryPolicy(
            maxRetryCount: 7,
            baseDelay: 2.0,
            multiplier: 1.5,
            maxDelay: 60.0,
            jitterFactor: 0.3
        )
    }
}