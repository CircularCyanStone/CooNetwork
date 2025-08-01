//
//  RetryTestManager.swift
//  CooNetwork
//
//  Created by Trae Builder on 2024/12/19.
//  请求重试功能测试管理器
//

import Foundation
import SwiftUI
import NtkNetwork

/// 请求重试测试管理器
/// 提供各种重试场景的测试方法
@MainActor
class RetryTestManager: ObservableObject {
    
    @Published var testResults: [String] = []
    @Published var isTestingExponential = false
    @Published var isTestingFast = false
    @Published var isTestingCustom = false
    
    /// 添加测试结果
    private func addResult(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testResults.append("[\(timestamp)] \(message)")
    }
    
    /// 清空测试结果
    func clearResults() {
        testResults.removeAll()
    }
    
    /// 测试指数退避重试策略
    /// 使用标准的指数退避重试策略进行测试
    func testExponentialBackoffRetry() {
        guard !isTestingExponential else { return }
        
        isTestingExponential = true
        addResult("开始指数退避重试测试...")
        
        Task {
            do {
                let req = Login.sendSMS("invalid_user_id", tmpLogin: false) // 使用无效ID触发错误
                
                addResult("使用指数退避重试策略（最多3次重试）")
                
                let _: CodeData = try await DefaultCoo.with(req)
                    .retryExponentialBackoff(
                        maxRetryCount: 3,
                        baseDelay: 1.0,
                        multiplier: 2.0,
                        maxDelay: 10.0,
                        jitterFactor: 0.1
                    )
                    .sendRequest().data
                
                await MainActor.run {
                    addResult("指数退避重试测试成功")
                    isTestingExponential = false
                }
            } catch {
                await MainActor.run {
                    addResult("指数退避重试测试完成（预期失败）: \(error.localizedDescription)")
                    isTestingExponential = false
                }
            }
        }
    }
    
    /// 测试快速重试策略
    /// 使用预定义的快速重试策略
    func testFastRetry() {
        guard !isTestingFast else { return }
        
        isTestingFast = true
        addResult("开始快速重试测试...")
        
        Task {
            do {
                let req = Login.sendSMS("test_retry_user", tmpLogin: false)
                
                addResult("使用快速重试策略")
                
                let _: CodeData = try await DefaultCoo.with(req)
                    .retry(NtkExponentialBackoffRetryPolicy.fast)
                    .sendRequest().data
                
                await MainActor.run {
                    addResult("快速重试测试成功")
                    isTestingFast = false
                }
            } catch {
                await MainActor.run {
                    addResult("快速重试测试完成（可能失败）: \(error.localizedDescription)")
                    isTestingFast = false
                }
            }
        }
    }
    
    /// 测试自定义重试策略
    /// 创建并测试自定义的重试策略
    func testCustomRetry() {
        guard !isTestingCustom else { return }
        
        isTestingCustom = true
        addResult("开始自定义重试测试...")
        
        Task {
            do {
                let req = Login.sendSMS("custom_test_user", tmpLogin: false)
                
                // 创建自定义重试策略
                let customRetryPolicy = await NtkExponentialBackoffRetryPolicy(
                    maxRetryCount: 2,
                    baseDelay: 0.5,
                    multiplier: 1.5,
                    maxDelay: 5.0,
                    jitterFactor: 0.2
                )
                
                addResult("使用自定义重试策略（最多2次重试，基础延迟0.5秒）")
                
                let _: CodeData = try await DefaultCoo.with(req)
                    .retry(customRetryPolicy)
                    .sendRequest().data
                
                await MainActor.run {
                    addResult("自定义重试测试成功")
                    isTestingCustom = false
                }
            } catch {
                await MainActor.run {
                    addResult("自定义重试测试完成（可能失败）: \(error.localizedDescription)")
                    isTestingCustom = false
                }
            }
        }
    }
    
    /// 测试无重试请求
    /// 对比测试，验证没有重试策略时的行为
    func testNoRetry() {
        addResult("开始无重试测试...")
        
        Task {
            do {
                let req = Login.sendSMS("no_retry_user", tmpLogin: false)
                
                addResult("发送无重试策略的请求")
                
                let _: CodeData = try await DefaultCoo.with(req)
                    .sendRequest().data
                
                await MainActor.run {
                    addResult("无重试测试成功")
                }
            } catch {
                await MainActor.run {
                    addResult("无重试测试失败（预期行为）: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 测试重试与缓存结合
    /// 验证重试策略与缓存功能的配合
    func testRetryWithCache() {
        addResult("开始重试+缓存测试...")
        
        Task {
            do {
                let req = Login.sendSMS("300343", tmpLogin: false)
                
                // 先尝试加载缓存
                let network = await DefaultCoo<CodeData>.with(req)
                    .retry(NtkExponentialBackoffRetryPolicy.standard)
                
                if let _: CodeData = try await network.loadCache()?.data {
                    await MainActor.run {
                        addResult("从缓存加载数据成功")
                    }
                } else {
                    addResult("缓存中无数据，发起网络请求")
                    let _: CodeData = try await network.sendRequest().data
                    await MainActor.run {
                        addResult("重试+缓存测试：网络请求成功")
                    }
                }
            } catch {
                await MainActor.run {
                    addResult("重试+缓存测试失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 测试不同重试策略的性能对比
    /// 比较不同重试策略的执行时间
    func testRetryPerformanceComparison() {
        addResult("开始重试性能对比测试...")
        
        Task {
            // 测试快速重试策略的执行时间
            let fastStartTime = Date()
            do {
                let req = Login.sendSMS("perf_test_fast", tmpLogin: false)
                let _: CodeData = try await DefaultCoo.with(req)
                    .retry(NtkExponentialBackoffRetryPolicy.fast)
                    .sendRequest().data
            } catch {
                // 忽略错误，只关注执行时间
            }
            let fastDuration = Date().timeIntervalSince(fastStartTime)
            
            await MainActor.run {
                addResult("快速重试策略执行时间: \(String(format: "%.2f", fastDuration))秒")
            }
            
            // 等待一段时间再测试标准策略
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            
            // 测试标准重试策略的执行时间
            let standardStartTime = Date()
            do {
                let req = Login.sendSMS("perf_test_standard", tmpLogin: false)
                let _: CodeData = try await DefaultCoo.with(req)
                    .retry(NtkExponentialBackoffRetryPolicy.standard)
                    .sendRequest().data
            } catch {
                // 忽略错误，只关注执行时间
            }
            let standardDuration = Date().timeIntervalSince(standardStartTime)
            
            await MainActor.run {
                addResult("标准重试策略执行时间: \(String(format: "%.2f", standardDuration))秒")
                addResult("重试性能对比测试完成")
            }
        }
    }
}
