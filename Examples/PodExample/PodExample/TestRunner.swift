//
//  TestRunner.swift
//  PodExample
//
//  Created by Claude Code on 2026/3/15.
//

import Foundation
import CooNetwork

// MARK: - Test Runner Actor

actor TestRunner {
    var results: [TestResult] = []
    var logBuffer: [String] = []
    var isRunning = false

    func runSuite(_ suite: TestSuite) async -> TestResult {
        let startTime = Date()
        log("🧪 Running: \(suite.name)")

        do {
            let result = try await suite.action()
            log("✅ Completed: \(suite.name) in \(String(format: "%.2f", result.duration))s")
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            log("❌ Failed: \(suite.name) - \(error)")
            return TestResult(
                name: suite.name,
                status: .failed,
                duration: duration,
                details: error.localizedDescription,
                evidence: nil
            )
        }
    }

    func runAll(suites: [TestSuite]) async -> [TestResult] {
        guard !isRunning else { return results }

        isRunning = true
        results.removeAll()
        logBuffer.removeAll()

        for suite in suites {
            let result = await runSuite(suite)
            results.append(result)
        }

        isRunning = false
        return results
    }

    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        logBuffer.append(logMessage)
        print(logMessage)
    }

    func generateReport() -> String {
        var report = "# CooNetwork 集成测试报告\n\n"
        report += "**测试时间**: \(Date())\n"
        report += "**测试环境**: iOS Simulator\n\n"

        let passedCount = results.filter { $0.status == .passed }.count
        let failedCount = results.filter { $0.status == .failed }.count
        let skippedCount = results.filter { $0.status == .skipped }.count
        let totalDuration = results.reduce(0) { $0 + $1.duration }

        report += "## 测试摘要\n\n"
        report += "| 指标 | 数值 |\n"
        report += "|------|------|\n"
        report += "| 总测试数 | \(results.count) |\n"
        report += "| 通过数 | \(passedCount) |\n"
        report += "| 失败数 | \(failedCount) |\n"
        report += "| 跳过数 | \(skippedCount) |\n"
        report += "| 总耗时 | \(String(format: "%.2f", totalDuration))s |\n\n"

        report += "## 详细结果\n\n"
        for result in results {
 {
            report += "### \(result.status.emoji) \(result.name) (\(String(format: "%.2f", result.duration))s)\n"
            report += "**状态**: \(result.status.displayName)\n"
            report += "**详情**: \(result.details)\n"
            if let evidence = result.evidence {
                report += "**Evidence**:\n```\n\(evidence)\n```\n"
            }
            report += "\n"
        }

        return report
    }
}

// MARK: - Logger Monitor

class NtkLoggerTestMonitor {
    private var capturedLogs: [String] = []
    private var originalLogLevel: NtkLogLevel = .info

    func attach() {
        capturedLogs.removeAll()

        // 保存当前日志级别
        originalLogLevel = NtkConfiguration.shared.logLevel

        // 确保日志开启
        NtkConfiguration.shared.isLoggingEnabled = true
        NtkConfiguration.shared.logLevel = .debug
    }

    func detach() {
        // 恢复原始日志级别
        NtkConfiguration.shared.logLevel = originalLogLevel
    }

    func captureLog(_ message: String) {
        capturedLogs.append(message)
    }

    func assertContains(_ expected: String) -> Bool {
        return capturedLogs.contains { $0.contains(expected) }
    }

    func assertContainsAll(_ expected: [String]) -> Bool {
        return expected.allSatisfy { assertContains($0) }
    }

    func getLogsByCategory(_ category: String) -> [String] {
        return capturedLogs.filter { $0.contains(category) }
    }

    var allLogs: String {
        return capturedLogs.joined(separator: "\n")
    }
}

// MARK: - Memory Monitor

class MemoryMonitor {
    private var measurements: [Measurement] = []

    struct Measurement {
        let timestamp: Date
        let memoryUsage: UInt64
    }

    func record() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let memoryUsage = result == KERN_SUCCESS ? info.resident_size : 0
        measurements.append(Measurement(timestamp: Date(), memoryUsage: memoryUsage))
    }

    func compare(after interval: TimeInterval = 1.0) -> MemoryComparison {
        guard measurements.count >= 2 else {
            return MemoryComparison(delta: 0, increased: false, percentage: 0)
        }

        let before = measurements.first!
        let after = measurements.last!
        let delta = after.memoryUsage - before.memoryUsage
        let percentage = before.memoryUsage > 0 ? Double(delta) / Double(before.memoryUsage) * 100 : 0

        return MemoryComparison(
            delta: delta,
            increased: delta > 0,
            percentage: percentage
        )
    }

    func reset() {
        measurements.removeAll()
    }

    struct MemoryComparison {
        let delta: UInt64
        let increased: Bool
        let percentage: Double

        var description: String {
            let mb = Double(delta) / 1024 / 1024
            return increased
                ? "内存增加 \(String(format: "%.2f", mb)) MB (\(String(format: "%.2f", percentage))%)"
                : "内存减少 \(String(format: "%.2f", abs(delta))) MB"
        }
    }
}
