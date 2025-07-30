//
//  NtkRequestDeduplicationManager.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求去重管理器
/// 负责管理正在进行的请求，实现请求去重逻辑
/// 通过请求标识符识别相同请求，避免重复发送
@NtkActor
class NtkRequestDeduplicationManager {
    
    /// 单例实例
    static let shared = NtkRequestDeduplicationManager()
    
    /// 正在进行的请求映射表
    /// Key: 请求标识符, Value: 正在执行的Task
    private var ongoingRequests: [String: Task<Sendable, Error>] = [:]
    
    /// 私有初始化方法
    private init() {}
    
    /// 执行请求（带去重逻辑和超时控制）
    /// 如果相同请求正在进行中，则等待其完成并返回相同结果
    /// 如果是新请求，则创建新的Task执行，并使用TaskGroup实现超时控制
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - execution: 实际的请求执行闭包
    /// - Returns: 请求结果
    func executeWithDeduplication<T: Sendable>(
        request: any iNtkRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let requestId = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        NtkDeduplicationLogger.log("请求标识符: \(requestId)", level: .debug)
        
        // 检查是否有相同请求正在进行
        if let ongoingTask = ongoingRequests[requestId] {
            NtkDeduplicationLogger.log("发现重复请求，等待现有请求完成: \(requestId)", level: .info)
            // 等待正在进行的请求完成
            do {
                let result = try await ongoingTask.value
                if let typedResult = result as? T {
                    NtkDeduplicationLogger.log("重复请求完成，返回共享结果: \(requestId)", level: .info)
                    return typedResult
                } else {
                    // 类型不匹配，移除缓存的Task并重新执行
                    ongoingRequests.removeValue(forKey: requestId)
                    return try await executeNewRequestWithTimeout(requestId: requestId, request: request, execution: execution)
                }
            } catch {
                // 正在进行的请求失败，移除缓存并重新执行
                ongoingRequests.removeValue(forKey: requestId)
                NtkDeduplicationLogger.log("现有请求失败，重新执行: \(requestId), 错误: \(error)", level: .warning)
                throw error
            }
        } else {
            // 执行新请求
            NtkDeduplicationLogger.log("创建新请求任务: \(requestId)", level: .debug)
            return try await executeNewRequestWithTimeout(requestId: requestId, request: request, execution: execution)
        }
    }
    
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
                throw NtkError.Deduplication.requestTimeout
            }
            
            // 等待第一个完成的任务
            guard let result = try await group.next() else {
                throw NtkError.Deduplication.requestCancelled
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
        request: any iNtkRequest,
        execution: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = request.timeout
        
        // 创建带超时控制的Task
        let task = Task<Sendable, Error> {
            return try await executeWithTimeout(timeout: timeout, execution: execution)
        }
        
        // 缓存Task
        ongoingRequests[requestId] = task
        
        do {
            // 执行请求
            let result = try await task.value
            
            // 请求完成，移除缓存
            ongoingRequests.removeValue(forKey: requestId)
            NtkDeduplicationLogger.log("请求成功完成: \(requestId)", level: .debug)
            
            if let typedResult = result as? T {
                return typedResult
            } else {
                throw NtkError.Deduplication.typeMismatch
            }
        } catch {
            // 请求失败或超时，移除缓存
            ongoingRequests.removeValue(forKey: requestId)
            
            if error is NtkError.Deduplication {
                switch error as! NtkError.Deduplication {
                case .requestTimeout:
                    NtkDeduplicationLogger.log("请求超时: \(requestId), 超时时间: \(timeout)秒", level: .warning)
                default:
                    NtkDeduplicationLogger.log("请求执行失败: \(requestId), 错误: \(error)", level: .error)
                }
            } else {
                NtkDeduplicationLogger.log("请求执行失败: \(requestId), 错误: \(error)", level: .error)
            }
            
            throw error
        }
    }
    
    /// 取消指定请求
    /// - Parameter request: 要取消的请求
    func cancelRequest(request: any iNtkRequest) {
        let requestId = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        if let task = ongoingRequests[requestId] {
            task.cancel()
            ongoingRequests.removeValue(forKey: requestId)
        }
    }
    
    /// 取消所有正在进行的请求
    func cancelAllRequests() {
        for (_, task) in ongoingRequests {
            task.cancel()
        }
        ongoingRequests.removeAll()
    }
    
    /// 获取正在进行的请求数量
    /// - Returns: 正在进行的请求数量
    func getOngoingRequestCount() -> Int {
        return ongoingRequests.count
    }
    
    /// 检查指定请求是否正在进行中
    /// - Parameter request: 要检查的请求
    /// - Returns: 是否正在进行中
    func isRequestOngoing(request: any iNtkRequest) -> Bool {
        let requestId = NtkRequestIdentifierManager.shared.getRequestIdentifier(request: request)
        return ongoingRequests[requestId] != nil
    }
}
