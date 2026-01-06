//
//  NtkTaskManager.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 网络请求任务管理器
/// 负责统一管理网络请求的Task生命周期，包括去重、超时控制和取消操作
/// 通过请求标识符识别相同请求，实现请求去重和Task复用
/// 使用静态存储避免单例模式，支持局部实例化
@NtkActor
class NtkTaskManager {
    
    /// 正在进行的请求映射表（静态存储，全局共享）
    /// Key: 请求标识符, Value: 正在执行的Task
    private static var ongoingRequests: [String: Task<Sendable, Error>] = [:]
    
    /// 执行请求（带去重逻辑和超时控制）
    /// 如果相同请求正在进行中，则等待其完成并返回相同结果
    /// 如果是新请求，则创建新的Task执行，并使用TaskGroup实现超时控制
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    func executeWithDeduplication<T: Sendable>(
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // 获取请求标识符（无论是否启用去重都需要正确的ID用于管理）
        let requestId = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        
        // 检查全局去重配置
        guard NtkDeduplicationConfig.shared.isGloballyEnabled else {
            NtkLogger.shared.debug("Global deduplication is disabled, executing with timeout only", category: .deduplication)
            return try await executeNewRequestWithTimeout(requestId: requestId, request: request, execution: execution)
        }
        
        // 检查请求是否启用去重
        guard request.isDeduplicationEnabled else {
            NtkLogger.shared.debug("Request deduplication is disabled, executing with timeout only", category: .deduplication)
            return try await executeNewRequestWithTimeout(requestId: requestId, request: request, execution: execution)
        }
        NtkLogger.shared.debug("请求标识符: \(requestId)", category: .deduplication)
        
        // 检查是否有相同请求正在进行
        if let ongoingTask = Self.ongoingRequests[requestId] {
            NtkLogger.shared.info("发现重复请求，等待现有请求完成: \(requestId)", category: .deduplication)
            // 等待正在进行的请求完成
            do {
                let result = try await ongoingTask.value
                if let typedResult = result as? T {
                    NtkLogger.shared.info("重复请求完成，返回共享结果: \(requestId)", category: .deduplication)
                    return typedResult
                } else {
                    // 类型不匹配，移除缓存的Task并重新执行
                    Self.ongoingRequests.removeValue(forKey: requestId)
                    return try await executeNewRequestWithTimeout(requestId: requestId, request: request, execution: execution)
                }
            } catch {
                // 正在进行的请求失败，移除缓存并重新执行
                Self.ongoingRequests.removeValue(forKey: requestId)
                NtkLogger.shared.warning("现有请求失败，重新执行: \(requestId), 错误: \(error)", category: .deduplication)
                throw error
            }
        } else {
            // 执行新请求
            NtkLogger.shared.debug("创建新请求任务: \(requestId)", category: .deduplication)
            return try await executeNewRequestWithTimeout(requestId: requestId, request: request, execution: execution)
        }
    }
    

    
    /// 取消指定请求
    /// - Parameter request: 要取消的请求
    static func cancelRequest(request: NtkMutableRequest) {
        let requestId = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        if let task = ongoingRequests[requestId] {
            task.cancel()
            ongoingRequests.removeValue(forKey: requestId)
        }
    }
    
    /// 取消所有正在进行的请求
    static func cancelAllRequests() {
        for (_, task) in ongoingRequests {
            task.cancel()
        }
        ongoingRequests.removeAll()
    }
    
    /// 获取当前活跃请求数量
    /// - Returns: 正在进行的请求数量
    static func activeRequestCount() -> Int {
        return ongoingRequests.count
    }
    
    /// 检查指定请求是否处于活跃状态
    /// - Parameter request: 要检查的请求
    /// - Returns: 请求是否正在执行中
    static func isRequestActive(request: NtkMutableRequest) -> Bool {
        let requestId = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        return ongoingRequests[requestId] != nil
    }
}

// MARK: - Private Methods
extension NtkTaskManager {
    
    /// 执行带超时控制的请求（通用方法）
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    private func executeWithTimeout<T: Sendable>(
        timeout: TimeInterval,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 添加实际请求任务
            group.addTask {
                return try await execution()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NtkError.requestTimeout
            }
            
            // 等待第一个完成的任务
            guard let result = try await group.next() else {
                throw NtkError.requestCancelled
            }
            
            // 取消其他任务
            group.cancelAll()
            
            return result
        }
    }
    
    /// 执行新请求（带超时控制和去重缓存）
    /// - Parameters:
    ///   - requestId: 请求标识符
    ///   - request: 网络请求对象
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    private func executeNewRequestWithTimeout<T: Sendable>(
        requestId: String,
        request: NtkMutableRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = request.timeout
        
        // 创建带超时控制的Task
        let task = Task<Sendable, Error> {
            return try await executeWithTimeout(timeout: timeout, execution: execution)
        }
        
        // 缓存Task
        Self.ongoingRequests[requestId] = task
        
        do {
            // 等待请求结果
            let result = try await task.value
            
            // 请求完成，移除缓存
            Self.ongoingRequests.removeValue(forKey: requestId)
            NtkLogger.shared.debug("请求成功完成: \(requestId)", category: .deduplication)
            
            if let typedResult = result as? T {
                return typedResult
            } else {
                throw NtkError.typeMismatch
            }
        } catch let error as NtkError {
            // 请求失败或超时，移除缓存
            Self.ongoingRequests.removeValue(forKey: requestId)
            if case .requestTimeout = error {
                NtkLogger.shared.warning("请求超时: \(requestId), 超时时间: \(timeout)秒", category: .deduplication)
            }else {
                NtkLogger.shared.error("请求执行失败: \(requestId), 错误: \(error)", category: .deduplication)
            }
            throw error
        } catch {
            NtkLogger.shared.error("请求执行失败: \(requestId), 错误: \(error)", category: .deduplication)
            throw error
        }
    }
}
