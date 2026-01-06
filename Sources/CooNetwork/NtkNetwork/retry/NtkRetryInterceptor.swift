//
//  NtkRetryInterceptor.swift
//  CNtk
//
//  重试拦截器实现
//

import Foundation

/// 重试拦截器
/// 负责在请求失败时根据重试策略进行重试
public struct NtkRetryInterceptor: iNtkInterceptor {
    /// 重试策略
    private let retryPolicy: iNtkRetryPolicy
    
    /// 拦截器优先级
    public let priority: NtkInterceptorPriority
    
    /// 初始化重试拦截器
    /// - Parameters:
    ///   - retryPolicy: 重试策略
    ///   - priority: 拦截器优先级，默认为高优先级
    public init(
        retryPolicy: iNtkRetryPolicy,
        priority: NtkInterceptorPriority = .priority(.high)
    ) {
        self.retryPolicy = retryPolicy
        self.priority = priority
    }
    
    public func intercept(context: NtkInterceptorContext, next: NtkRequestHandler) async throws -> any iNtkResponse {
        var attemptCount = 0
        var lastError: Error?
        
        // 执行重试循环
        while attemptCount < retryPolicy.maxRetryCount {
            attemptCount += 1
            
            do {
                // 尝试执行请求
                let response = try await next.handle(context: context)
                // 请求成功，记录重试统计信息
                if attemptCount > 1 {
                    await recordRetrySuccess(attemptCount: attemptCount - 1)
                }
                return response
            } catch {
                lastError = error
                
                // 检查是否应该重试
                guard retryPolicy.shouldRetry(attemptCount: attemptCount, error: error) else {
                    // 不应该重试，记录失败并抛出错误
                    await recordRetryFailure(attemptCount: attemptCount - 1, finalError: error)
                    throw error
                }
                
                // 如果已达到最大重试次数，抛出错误
                guard attemptCount < retryPolicy.maxRetryCount else {
                    await recordRetryFailure(attemptCount: attemptCount - 1, finalError: error)
                    throw error
                }
                
                // 计算延迟时间
                guard let delay = retryPolicy.retryDelay(for: attemptCount, error: error) else {
                    // 策略返回nil，不应该重试
                    await recordRetryFailure(attemptCount: attemptCount - 1, finalError: error)
                    throw error
                }
                
                // 记录重试尝试
                await recordRetryAttempt(attemptCount: attemptCount, delay: delay, error: error)
                
                // 延迟后重试
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 重试次数用完，抛出最后的错误
        let finalError = lastError ?? NtkError.other("Network timeout" as! Error)
        await recordRetryFailure(attemptCount: retryPolicy.maxRetryCount, finalError: finalError)
        throw finalError
    }
}

// MARK: - 重试统计和日志
private extension NtkRetryInterceptor {
    /// 记录重试尝试
    func recordRetryAttempt(
        attemptCount: Int,
        delay: TimeInterval,
        error: Error
    ) async {
        #if DEBUG
        print("[NtkRetry] Attempt \(attemptCount) failed, retrying in \(delay)s. Error: \(error)")
        #endif
        
        // 这里可以添加更详细的统计信息收集
        // 例如发送到分析服务或本地存储
    }
    
    /// 记录重试成功
    func recordRetrySuccess(
        attemptCount: Int
    ) async {
        #if DEBUG
        print("[NtkRetry] Request succeeded after \(attemptCount) retries")
        #endif
        
        // 记录成功的重试统计
    }
    
    /// 记录重试失败
    func recordRetryFailure(
        attemptCount: Int,
        finalError: Error
    ) async {
        #if DEBUG
        print("[NtkRetry] Request failed after \(attemptCount) retries. Final error: \(finalError)")
        #endif
        
        // 记录失败的重试统计
    }
}

// MARK: - 便利构造器
extension NtkRetryInterceptor {
    /// 使用指数退避策略的重试拦截器
    static func exponentialBackoff(
        maxRetryCount: Int = 3,
        baseDelay: TimeInterval = 1.0,
        multiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        jitterFactor: Double = 0.1
    ) -> NtkRetryInterceptor {
        let policy = NtkExponentialBackoffRetryPolicy(
            maxRetryCount: maxRetryCount,
            baseDelay: baseDelay,
            multiplier: multiplier,
            maxDelay: maxDelay,
            jitterFactor: jitterFactor
        )
        return NtkRetryInterceptor(retryPolicy: policy)
    }
    
    /// 使用固定间隔策略的重试拦截器
    static func fixedInterval(
        maxRetryCount: Int = 3,
        interval: TimeInterval = 2.0,
        jitterFactor: Double = 0.1
    ) -> NtkRetryInterceptor {
        let policy = NtkFixedIntervalRetryPolicy(
            maxRetryCount: maxRetryCount,
            interval: interval,
            jitterFactor: jitterFactor
        )
        return NtkRetryInterceptor(retryPolicy: policy)
    }
}
