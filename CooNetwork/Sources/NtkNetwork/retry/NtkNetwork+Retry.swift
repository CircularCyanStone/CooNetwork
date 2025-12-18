//
//  NtkNetwork+Retry.swift
//  CNtk
//
//  为NtkNetwork添加重试功能扩展
//

import Foundation

// MARK: - NtkNetwork重试扩展
extension NtkNetwork {
    /// 添加重试拦截器
    /// - Parameter retryInterceptor: 重试拦截器
    /// - Returns: 返回自身以支持链式调用
    @discardableResult
    public func retry(_ retryInterceptor: NtkRetryInterceptor) -> Self {
        return self.addInterceptor(retryInterceptor)
    }
    
    /// 添加自定义重试策略
    /// - Parameter retryPolicy: 重试策略
    /// - Returns: 返回自身以支持链式调用
    @discardableResult
    public func retry(_ retryPolicy: iNtkRetryPolicy) -> Self {
        let retryInterceptor = NtkRetryInterceptor(retryPolicy: retryPolicy)
        return retry(retryInterceptor)
    }
    
    /// 使用指数退避重试策略
    /// - Parameters:
    ///   - maxRetryCount: 最大重试次数，默认3次
    ///   - baseDelay: 基础延迟时间，默认1秒
    ///   - multiplier: 指数倍数，默认2.0
    ///   - maxDelay: 最大延迟时间，默认30秒
    ///   - jitterFactor: 随机抖动因子，默认0.1
    /// - Returns: 返回自身以支持链式调用
    @discardableResult
    public func retryExponentialBackoff(
        maxRetryCount: Int = 3,
        baseDelay: TimeInterval = 1.0,
        multiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        jitterFactor: Double = 0.1
    ) -> Self {
        let retryInterceptor = NtkRetryInterceptor.exponentialBackoff(
            maxRetryCount: maxRetryCount,
            baseDelay: baseDelay,
            multiplier: multiplier,
            maxDelay: maxDelay,
            jitterFactor: jitterFactor
        )
        return retry(retryInterceptor)
    }
    
    /// 使用固定间隔重试策略
    /// - Parameters:
    ///   - maxRetryCount: 最大重试次数，默认3次
    ///   - interval: 固定延迟时间，默认2秒
    ///   - jitterFactor: 随机抖动因子，默认0.1
    /// - Returns: 返回自身以支持链式调用
    @discardableResult
    public func retryFixedInterval(
        maxRetryCount: Int = 3,
        interval: TimeInterval = 2.0,
        jitterFactor: Double = 0.1
    ) -> Self {
        let retryInterceptor = NtkRetryInterceptor.fixedInterval(
            maxRetryCount: maxRetryCount,
            interval: interval,
            jitterFactor: jitterFactor
        )
        return retry(retryInterceptor)
    }
}

// MARK: - 预设重试策略扩展
extension NtkNetwork {
    /// 快速重试：指数退避，最多3次，延迟较短
    /// 适用于对响应时间要求较高的场景
    @discardableResult
    public func retryFast() -> Self {
        return retry(NtkExponentialBackoffRetryPolicy.fast)
    }
    
    /// 标准重试：指数退避，最多5次，中等延迟
    /// 适用于大多数网络请求场景
    @discardableResult
    public func retryStandard() -> Self {
        return retry(NtkExponentialBackoffRetryPolicy.standard)
    }
    
    /// 慢速重试：指数退避，最多7次，延迟较长
    /// 适用于对成功率要求较高，可以容忍较长等待时间的场景
    @discardableResult
    public func retrySlow() -> Self {
        return retry(NtkExponentialBackoffRetryPolicy.slow)
    }
    
    /// 固定间隔快速重试：最多3次，间隔1秒
    /// 适用于预期很快恢复的临时性故障
    @discardableResult
    public func retryFixedFast() -> Self {
        return retry(NtkFixedIntervalRetryPolicy.fast)
    }
    
    /// 固定间隔标准重试：最多5次，间隔2秒
    /// 适用于需要稳定间隔的重试场景
    @discardableResult
    public func retryFixedStandard() -> Self {
        return retry(NtkFixedIntervalRetryPolicy.standard)
    }
    
    /// 固定间隔慢速重试：最多7次，间隔5秒
    /// 适用于服务器负载较高，需要给服务器更多恢复时间的场景
    @discardableResult
    public func retryFixedSlow() -> Self {
        return retry(NtkFixedIntervalRetryPolicy.slow)
    }
}
