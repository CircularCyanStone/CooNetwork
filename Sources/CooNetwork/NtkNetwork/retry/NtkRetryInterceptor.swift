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
        priority: NtkInterceptorPriority = .high
    ) {
        self.retryPolicy = retryPolicy
        self.priority = priority
    }
    
    /// 拦截请求并在失败时按策略重试
    ///
    /// 执行流程：首次执行 + 最多 maxRetryCount 次重试
    /// - maxRetryCount=0：只执行一次，不重试
    /// - maxRetryCount=3：首次执行 + 最多 3 次重试 = 最多 4 次执行
    @NtkActor
    public func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        // 首次执行
        do {
            return try await next.handle(context: context)
        } catch {
            // 首次失败，检查是否需要重试
            guard retryPolicy.maxRetryCount > 0,
                  retryPolicy.shouldRetry(attemptCount: 1, error: error) else {
                throw error
            }

            // 进入重试循环
            return try await retryLoop(context: context, next: next, firstError: error)
        }
    }

    /// 重试循环（首次执行已失败后调用）
    private func retryLoop(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler,
        firstError: Error
    ) async throws -> any iNtkResponse {
        var lastError = firstError
        var retryCount = 0

        while retryCount < retryPolicy.maxRetryCount {
            retryCount += 1

            // 计算延迟时间
            guard let delay = retryPolicy.retryDelay(for: retryCount, error: lastError) else {
                await recordRetryFailure(retryCount: retryCount - 1, finalError: lastError)
                throw lastError
            }

            await recordRetryAttempt(retryCount: retryCount, delay: delay, error: lastError)

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                let response = try await next.handle(context: context)
                await recordRetrySuccess(retryCount: retryCount)
                return response
            } catch {
                lastError = error

                // 检查是否继续重试
                guard retryPolicy.shouldRetry(attemptCount: retryCount + 1, error: error) else {
                    await recordRetryFailure(retryCount: retryCount, finalError: error)
                    throw error
                }
            }
        }

        // 重试次数用完
        await recordRetryFailure(retryCount: retryCount, finalError: lastError)
        throw lastError
    }
}

// MARK: - 重试统计和日志
private extension NtkRetryInterceptor {
    /// 记录重试尝试
    func recordRetryAttempt(
        retryCount: Int,
        delay: TimeInterval,
        error: Error
    ) async {
        logger.debug("[NtkRetry] Retry #\(retryCount) in \(delay)s. Error: \(error)", category: .retry)
    }

    /// 记录重试成功
    func recordRetrySuccess(retryCount: Int) async {
        logger.debug("[NtkRetry] Request succeeded after \(retryCount) retries", category: .retry)
    }

    /// 记录重试失败
    func recordRetryFailure(retryCount: Int, finalError: Error) async {
        logger.error("[NtkRetry] Request failed after \(retryCount) retries. Final error: \(finalError)", category: .retry)
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
