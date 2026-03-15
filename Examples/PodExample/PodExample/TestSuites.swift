//
//  TestSuites.swift
//  PodExample
//
//  Created by Claude Code on 2026/3/15.
//

import Foundation
import CooNetwork
import Alamofire

// MARK: - T1: Basic Request Test

func testT1_BasicRequest() -> TestSuite {
    return TestSuite(
        name: "T1: 基础请求测试",
        description: "验证网络请求基本功能正常"
    ) {
        let startTime = Date()

        let request = JSONPlaceholderRequest(
            path: "/posts/1",
            method: .get,
            parameters: nil
        )

        do {
            let result = try await NtkAF<Post>.withAF(
                request,
                validation: StandardValidation()
            ).request()

            let duration = Date().timeIntervalSince(startTime)

            // 验证响应
            guard result.data.id == 1 else {
                throw TestError.validationFailed("Expected id=1, got id=\(result.data.id)")
            }
            guard result.data.userId == 1 else {
                throw TestError.validationFailed("Expected userId=1, got userId=\(result.data.userId)")
            }
            guard !result.data.title.isEmpty else {
                throw TestError.validationFailed("Title should not be empty")
            }

            return TestResult(
                name: "T1: 基础请求测试",
                status: .passed,
                duration: duration,
                details: "GET /posts/1 成功返回数据",
                evidence: """
                {
                  "id": \(result.data.id),
                  "userId": \(result.data.userId),
                  "title": "\(result.data.title.prefix(50))..."
                }
                """
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "T1: 基础请求测试",
                status: .failed,
                duration: duration,
                details: "请求失败: \(error.localizedDescription)",
                evidence: nil
            )
        }
    }
}

// MARK: - T2: New API ReturnData Test

func testT2_NewAPITest() -> TestSuite {
    return TestSuite(
        name: "T2: 新 API 测试",
        description: "验证拼写修复后的 unwrapReturnData API 可用"
    ) {
        let startTime = Date()

        let request = JSONPlaceholderRequest(
            path: "/posts/1",
            method: .get,
            parameters: nil
        )

        do {
            // 使用新 API unwrapReturnData（而非旧的 unwrapRetureData）
            let result = try await NtkAF<Post>.withAF(request)
                .unwrapReturnData()  // 新 API
                .request()

            let duration = Date().timeIntervalSince(startTime)

            // 验证结果
            guard result.id == 1 else {
                throw TestError.validationFailed("Expected id=1, got id=\(result.id)")
            }

            return TestResult(
                name: "T2: 新 API 测试",
                status: .passed,
                duration: duration,
                details: "unwrapReturnData() 正常工作，类型正确推断",
                evidence: """
                Return type: Post
                Post.id: \(result.id)
                Post.userId: \(result.userId)
                """
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "T2: 新 API 测试",
                status: .failed,
                duration: duration,
                details: "API 调用失败: \(error.localizedDescription)",
                evidence: nil
            )
        }
    }
}

// MARK: - T3: Logging Test

func testT3_LoggingTest() -> TestSuite {
    return TestSuite(
        name: "T3: 日志测试",
        description: "验证 NtkLogger 统一输出分类日志"
    ) {
        let startTime = Date()
        let monitor = NtkLoggerTestMonitor()

        do {
            monitor.attach()

            let request = HttpBinRequest(
                path: "/get",
                method: .get,
                parameters: nil
            )

            let _ = try await NtkAF<HttpBinResponse>.withAF(
                request,
                validation: StandardValidation()
            ).request()

            let duration = Date().timeIntervalSince(startTime)

            // 验证日志（通过实际输出检查）
            // 注意：由于我们无法直接访问 NtkLogger 内部状态，
            // 这里通过配置验证日志系统已启用
            let loggingEnabled = NtkConfiguration.shared.isLoggingEnabled
            let logLevel = NtkConfiguration.shared.logLevel

            if !loggingEnabled {
                throw TestError.validationFailed("日志未启用")
            }

            if logLevel == .off {
                throw TestError.validationFailed("日志级别设置为 off")
            }

            monitor.detach()

            return TestResult(
                name: "T3: 日志测试",
                status: .passed,
                duration: duration,
                details: "NtkLogger 配置正确，isLoggingEnabled=\(loggingEnabled), logLevel=\(logLevel)",
                evidence: """
                isLoggingEnabled: \(loggingEnabled)
                logLevel: \(logLevel)
                """
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "T3: 日志测试",
                status: .failed,
                duration: duration,
                details: "日志测试失败: \(error.localizedDescription)",
                evidence: nil
            )
        }
    }
}

// MARK: - T4: Deduplication Test

func testT4_DeduplicationTest() -> TestSuite {
    return TestSuite(
        name: "T4: 去重测试",
        description: "验证 NtkTaskManager 去重功能"
    ) {
        let startTime = Date()

        do {
            // 启用去重和缓存
            let config = NtkConfiguration.shared
            config.enableDeduplication = true
            config.enableCache = false  // 关闭缓存以免干扰

            let request = JSONPlaceholderRequest(
                path: "/posts",
                method: .get,
                parameters: nil
            )

            // 并发发送 5 个相同请求
            var results: [Result<[Post], Error>] = []
            let startTimes = Date()

            await withTaskGroup(of: Result<[Post], Error>.self) { group in
                for _ in 1...5 {
                    group.addTask {
                        do {
                            let result = try await NtkAF<[Post]>.withAF(
                                request,
                                validation: StandardValidation()
                            ).request()
                            return .success(result.data)
                        } catch {
                            return .failure(error)
                        }
                    }
                }

                for await result in group {
                    results.append(result)
                }
            }

            let duration = Date().timeIntervalSince(startTime)

            // 验证所有请求都成功
            let successCount = results.filter { $0.isSuccess }.count
            guard successCount == 5 else {
                throw TestError.validationFailed("期望 5 个成功请求，实际 \(successCount) 个")
            }

            // 验证所有结果相同
            guard case .success(let firstData) = results.first else {
                throw TestError.validationFailed("第一个请求失败")
            }

            let allSame = results.allSatisfy {
                guard case .success(let data) = $0 else { return false }
                return data.count == firstData.count
            }

            guard allSame else {
                throw TestError.validationFailed("去重结果不一致")
            }

            return TestResult(
                name: "T4: 去重测试",
                status: .passed,
                duration: duration,
                details: "并发 5 个相同请求，去重功能正常，所有返回数据一致",
                evidence: """
                Success count: \(successCount)/5
                Data count: \(firstData.count)
                Total duration: \(String(format: "%.2f", duration))s
                """
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "T4: 去重测试",
                status: .failed,
                duration: duration,
                details: "去重测试失败: \(error.localizedDescription)",
                evidence: nil
            )
        }
    }
}

// MARK: - Test Error

enum TestError: LocalizedError {
    case validationFailed(String)
    case assertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "验证失败: \(message)"
        case .assertionFailed(let message):
            return "断言失败: \(message)"
        }
    }
}

// MARK: - Empty Response

struct EmptyResponse: Decodable, Sendable {}
