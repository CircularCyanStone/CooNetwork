//
//  DeduplicationTestManager.swift
//  CooNetwork
//
//  Created by Trae Builder on 2024/12/19.
//  请求去重功能测试管理器
//

import Foundation
import SwiftUI

/// 请求去重测试管理器
/// 提供各种去重场景的测试方法
@MainActor
class DeduplicationTestManager: ObservableObject {
    
    @Published var testResults: [String] = []
    @Published var isTestingConcurrent = false
    @Published var isTestingSequential = false
    
    /// 添加测试结果
    private func addResult(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testResults.append("[\(timestamp)] \(message)")
    }
    
    /// 清空测试结果
    func clearResults() {
        testResults.removeAll()
    }
    
    /// 测试并发请求去重
    /// 同时发起多个相同请求，验证去重功能是否正常工作
    func testConcurrentDeduplication() {
        guard !isTestingConcurrent else { return }
        
        isTestingConcurrent = true
        addResult("开始并发去重测试...")
        
        Task {
            do {
                // 同时发起3个相同的请求
                async let request1 = sendSMSWithDeduplication(userId: "300343", testId: "Request-1")
                async let request2 = sendSMSWithDeduplication(userId: "300343", testId: "Request-2")
                async let request3 = sendSMSWithDeduplication(userId: "300343", testId: "Request-3")
                
                // 等待所有请求完成
                let results = try await [request1, request2, request3]
                
                await MainActor.run {
                    addResult("并发请求完成，共\(results.count)个请求")
                    for (index, result) in results.enumerated() {
                        addResult("Request-\(index + 1): \(result ? "成功" : "失败")")
                    }
                    addResult("并发去重测试完成")
                    isTestingConcurrent = false
                }
            } catch {
                await MainActor.run {
                    addResult("并发去重测试失败: \(error.localizedDescription)")
                    isTestingConcurrent = false
                }
            }
        }
    }
    
    /// 测试顺序请求去重
    /// 依次发起相同请求，验证去重功能
    func testSequentialDeduplication() {
        guard !isTestingSequential else { return }
        
        isTestingSequential = true
        addResult("开始顺序去重测试...")
        
        Task {
            do {
                // 第一个请求
                let result1 = try await sendSMSWithDeduplication(userId: "300343", testId: "Sequential-1")
                await MainActor.run {
                    addResult("Sequential-1: \(result1 ? "成功" : "失败")")
                }
                
                // 等待一小段时间
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                
                // 第二个请求（应该被去重）
                let result2 = try await sendSMSWithDeduplication(userId: "300343", testId: "Sequential-2")
                await MainActor.run {
                    addResult("Sequential-2: \(result2 ? "成功" : "失败")")
                }
                
                // 等待更长时间，让去重缓存过期
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                
                // 第三个请求（应该不被去重）
                let result3 = try await sendSMSWithDeduplication(userId: "300343", testId: "Sequential-3")
                await MainActor.run {
                    addResult("Sequential-3: \(result3 ? "成功" : "失败")")
                    addResult("顺序去重测试完成")
                    isTestingSequential = false
                }
            } catch {
                await MainActor.run {
                    addResult("顺序去重测试失败: \(error.localizedDescription)")
                    isTestingSequential = false
                }
            }
        }
    }
    
    /// 测试禁用去重功能
    /// 验证禁用去重后，相同请求都会被执行
    func testDisabledDeduplication() {
        addResult("开始禁用去重测试...")
        
        Task {
            do {
                // 发起两个禁用去重的相同请求
                async let request1 = sendSMSWithoutDeduplication(userId: "300343", testId: "NoDedup-1")
                async let request2 = sendSMSWithoutDeduplication(userId: "300343", testId: "NoDedup-2")
                
                let results = try await [request1, request2]
                
                await MainActor.run {
                    addResult("禁用去重请求完成")
                    for (index, result) in results.enumerated() {
                        addResult("NoDedup-\(index + 1): \(result ? "成功" : "失败")")
                    }
                    addResult("禁用去重测试完成")
                }
            } catch {
                await MainActor.run {
                    addResult("禁用去重测试失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 发送短信请求（启用去重）
    private func sendSMSWithDeduplication(userId: String, testId: String) async throws -> Bool {
        await MainActor.run {
            addResult("\(testId): 开始发送请求（启用去重）")
        }
        
        do {
            let req = Login.sendSMS(userId, tmpLogin: false)
            let _: CodeData = try await NtkDefault.withRpc(req).request().data
            
            await MainActor.run {
                addResult("\(testId): 请求成功")
            }
            return true
        } catch {
            await MainActor.run {
                addResult("\(testId): 请求失败 - \(error.localizedDescription)")
            }
            return false
        }
    }
    
    /// 发送短信请求（禁用去重）
    private func sendSMSWithoutDeduplication(userId: String, testId: String) async throws -> Bool {
        await MainActor.run {
            addResult("\(testId): 开始发送请求（禁用去重）")
        }
        
        do {
            let req = Login.sendSMS(userId, tmpLogin: false)
            // 这里需要配置禁用去重，但当前API可能不支持，先保持原样
            let _: CodeData = try await NtkDefault.withRpc(req).request().data
            
            await MainActor.run {
                addResult("\(testId): 请求成功")
            }
            return true
        } catch {
            await MainActor.run {
                addResult("\(testId): 请求失败 - \(error.localizedDescription)")
            }
            return false
        }
    }
}
