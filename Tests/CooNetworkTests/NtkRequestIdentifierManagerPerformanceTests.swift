//
//  NtkRequestIdentifierManagerPerformanceTests.swift
//  CooNetworkTests
//
//  Created by Coo on 2026/3/17.
//

import Foundation
import Testing

@testable import CooNetwork

/// NtkRequestIdentifierManager 性能测试
/// 测试缓存 key 的构建成本，对比缓存方案
@Suite struct NtkRequestIdentifierManagerPerformanceTests {

    // MARK: - 辅助类型

    /// 测试用的请求类型
    struct TestRequest: iNtkRequest {
        let userId: Int
        let token: String
        let headers: [String: String]

        var baseURL: URL? { URL(string: "https://api.example.com") }
        var path: String { "/user/info" }
        var method: NtkHTTPMethod { .get }
        var parameters: [String: any Sendable]? {
            [
                "id": userId,
                "token": token,
                "timestamp": Int(Date().timeIntervalSince1970),
                "extra": "this is some extra data for testing hash performance"
            ]
        }
        var requestHeaders: [String: String]? { headers }
        var requestConfiguration: NtkRequestConfiguration? {
            NtkRequestConfiguration(cacheTime: 3600, filteredParameterNames: ["timestamp"])
        }
    }

    /// 创建缓存配置
    func makeCacheConfig() -> NtkRequestConfiguration {
        NtkRequestConfiguration(cacheTime: 3600, filteredParameterNames: ["timestamp"])
    }

    // MARK: - 基础性能测试

    @Test("测试 generateHashForCache 单次调用性能")
    func testSingleHashPerformance() async throws {
        let request = TestRequest(
            userId: 1001,
            token: "test_token_abc123",
            headers: [
                "Authorization": "Bearer token123",
                "X-Request-ID": UUID().uuidString,
                "Content-Type": "application/json"
            ]
        )
        let mutableRequest = NtkMutableRequest(request)
        let cacheConfig = makeCacheConfig()

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = await NtkRequestIdentifierManager.shared.getCacheKey(
            request: mutableRequest,
            cacheConfig: cacheConfig
        )
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        print("单次 getCacheKey 耗时: \(String(format: "%.4f", elapsed)) 毫秒")
        #expect(elapsed < 10, "单次哈希计算应在 10 毫秒内完成")
    }

    @Test("测试 generateHashForCache 重复调用性能（无缓存）")
    func testRepeatedCallPerformanceWithoutCache() async throws {
        let request = TestRequest(
            userId: 1001,
            token: "test_token_abc123",
            headers: [
                "Authorization": "Bearer token123",
                "Content-Type": "application/json"
            ]
        )
        let mutableRequest = NtkMutableRequest(request)
        let cacheConfig = makeCacheConfig()

        let iterations = 10000
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            _ = await NtkRequestIdentifierManager.shared.getCacheKey(
                request: mutableRequest,
                cacheConfig: cacheConfig
            )
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let avgElapsed = elapsed / Double(iterations)

        print("\(iterations) 次调用总耗时: \(String(format: "%.4f", elapsed)) 毫秒")
        print("平均每次耗时: \(String(format: "%.4f", avgElapsed)) 毫秒")
    }

    @Test("测试不同请求的哈希性能")
    func testDifferentRequestsPerformance() async throws {
        let cacheConfig = makeCacheConfig()
        let iterations = 10000

        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 0..<iterations {
            let request = TestRequest(
                userId: 1000 + i,
                token: "token_\(i)",
                headers: [
                    "Authorization": "Bearer token\(i)",
                    "Content-Type": "application/json"
                ]
            )
            let mutableRequest = NtkMutableRequest(request)
            _ = await NtkRequestIdentifierManager.shared.getCacheKey(
                request: mutableRequest,
                cacheConfig: cacheConfig
            )
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let avgElapsed = elapsed / Double(iterations)

        print("\(iterations) 个不同请求总耗时: \(String(format: "%.4f", elapsed)) 毫秒")
        print("平均每个请求耗时: \(String(format: "%.4f", avgElapsed)) 毫秒")
    }

    // MARK: - RequestCacheKey 方案对比测试

    @Test("对比：原始方案 vs RequestCacheKey 方案")
    func compareOriginalVsRequestCacheKey() async throws {
        let request = TestRequest(
            userId: 1001,
            token: "test_token_abc123",
            headers: [
                "Authorization": "Bearer token123",
                "Content-Type": "application/json"
            ]
        )
        let mutableRequest = NtkMutableRequest(request)
        let cacheConfig = makeCacheConfig()

        let iterations = 10000

        // 原始方案：直接调用 getCacheKey（当前实现实际上没有缓存效果）
        let originalStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = await NtkRequestIdentifierManager.shared.getCacheKey(
                request: mutableRequest,
                cacheConfig: cacheConfig
            )
        }
        let originalTime = (CFAbsoluteTimeGetCurrent() - originalStartTime) * 1000

        print("\n=== 性能对比测试 (\(iterations)次调用) ===")
        print("原始方案（每次重新计算哈希）: \(String(format: "%.4f", originalTime)) 毫秒")
        print("平均每次: \(String(format: "%.4f", originalTime / Double(iterations))) 毫秒")

        // RequestCacheKey 方案：先构造 RequestCacheKey，再查询缓存
        let requestCacheKeyStartTime = CFAbsoluteTimeGetCurrent()
        var cache: [RequestCacheKey: String] = [:]
        let requestKey = RequestCacheKey(request: mutableRequest, cacheConfig: cacheConfig)

        for _ in 0..<iterations {
            if let cached = cache[requestKey] {
                _ = cached
            } else {
                let key = await NtkRequestIdentifierManager.shared.getCacheKey(
                    request: mutableRequest,
                    cacheConfig: cacheConfig
                )
                cache[requestKey] = key
            }
        }
        let requestCacheKeyTime = (CFAbsoluteTimeGetCurrent() - requestCacheKeyStartTime) * 1000

        print("RequestCacheKey 方案（使用缓存）: \(String(format: "%.4f", requestCacheKeyTime)) 毫秒")
        print("平均每次: \(String(format: "%.4f", requestCacheKeyTime / Double(iterations))) 毫秒")

        // 计算缓存构造开销
        let constructionStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = RequestCacheKey(request: mutableRequest, cacheConfig: cacheConfig)
        }
        let constructionTime = (CFAbsoluteTimeGetCurrent() - constructionStartTime) * 1000

        print("RequestCacheKey 构造开销 (\(iterations)次): \(String(format: "%.4f", constructionTime)) 毫秒")
        print("平均每次: \(String(format: "%.4f", constructionTime / Double(iterations))) 毫秒")

        // 计算性能提升
        if requestCacheKeyTime < originalTime {
            let improvement = (1.0 - Double(requestCacheKeyTime) / Double(originalTime)) * 100
            print("性能提升: \(String(format: "%.2f", improvement))%")
        } else {
            let overhead = (Double(requestCacheKeyTime) / Double(originalTime) - 1.0) * 100
            print("性能下降: \(String(format: "%.2f", overhead))%")
            print("结论: RequestCacheKey 构造成本抵消了缓存收益")
        }
    }

    @Test("对比：原始方案 vs RequestCacheKey 方案 (100000次)")
    func compareOriginalVsRequestCacheKey_100k() async throws {
        let request = TestRequest(
            userId: 1001,
            token: "test_token_abc123",
            headers: [
                "Authorization": "Bearer token123",
                "Content-Type": "application/json"
            ]
        )
        let mutableRequest = NtkMutableRequest(request)
        let cacheConfig = makeCacheConfig()

        let iterations = 100000

        // 原始方案：直接调用 getCacheKey（当前实现实际上没有缓存效果）
        let originalStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = await NtkRequestIdentifierManager.shared.getCacheKey(
                request: mutableRequest,
                cacheConfig: cacheConfig
            )
        }
        let originalTime = (CFAbsoluteTimeGetCurrent() - originalStartTime) * 1000

        print("\n=== 性能对比测试 (\(iterations)次调用) ===")
        print("原始方案（每次重新计算哈希）: \(String(format: "%.4f", originalTime)) 毫秒")
        print("平均每次: \(String(format: "%.4f", originalTime / Double(iterations))) 毫秒")

        // RequestCacheKey 方案：先构造 RequestCacheKey，再查询缓存
        let requestCacheKeyStartTime = CFAbsoluteTimeGetCurrent()
        var cache: [RequestCacheKey: String] = [:]
        let requestKey = RequestCacheKey(request: mutableRequest, cacheConfig: cacheConfig)

        for _ in 0..<iterations {
            if let cached = cache[requestKey] {
                _ = cached
            } else {
                let key = await NtkRequestIdentifierManager.shared.getCacheKey(
                    request: mutableRequest,
                    cacheConfig: cacheConfig
                )
                cache[requestKey] = key
            }
        }
        let requestCacheKeyTime = (CFAbsoluteTimeGetCurrent() - requestCacheKeyStartTime) * 1000

        print("RequestCacheKey 方案（使用缓存）: \(String(format: "%.4f", requestCacheKeyTime)) 毫秒")
        print("平均每次: \(String(format: "%.4f", requestCacheKeyTime / Double(iterations))) 毫秒")

        // 计算缓存构造开销
        let constructionStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = RequestCacheKey(request: mutableRequest, cacheConfig: cacheConfig)
        }
        let constructionTime = (CFAbsoluteTimeGetCurrent() - constructionStartTime) * 1000

        print("RequestCacheKey 构造开销 (\(iterations)次): \(String(format: "%.4f", constructionTime)) 毫秒")
        print("平均每次: \(String(format: "%.4f", constructionTime / Double(iterations))) 毫秒")

        // 计算性能提升
        if requestCacheKeyTime < originalTime {
            let improvement = (1.0 - Double(requestCacheKeyTime) / Double(originalTime)) * 100
            print("性能提升: \(String(format: "%.2f", improvement))%")
        } else {
            let overhead = (Double(requestCacheKeyTime) / Double(originalTime) - 1.0) * 100
            print("性能下降: \(String(format: "%.2f", overhead))%")
            print("结论: RequestCacheKey 构造成本抵消了缓存收益")
        }
    }

    @Test("测试大参数请求的哈希性能")
    func testLargeParametersPerformance() async throws {
        // 构造一个包含大量参数的请求
        var largeParams: [String: any Sendable] = [:]
        for i in 0..<100 {
            largeParams["param_\(i)"] = "value_\(i)_with_long_string_content_for_testing"
        }

        struct LargeRequest: iNtkRequest {
            let largeParams: [String: any Sendable]
            var baseURL: URL? { URL(string: "https://api.example.com") }
            var path: String { "/large/data" }
            var method: NtkHTTPMethod { .post }
            var parameters: [String: any Sendable]? { largeParams }
        }

        let largeRequest = LargeRequest(largeParams: largeParams)
        let mutableRequest = NtkMutableRequest(largeRequest)
        let cacheConfig = makeCacheConfig()

        print("\n=== 大参数请求测试 (100个参数) ===")
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = await NtkRequestIdentifierManager.shared.getCacheKey(
            request: mutableRequest,
            cacheConfig: cacheConfig
        )
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        print("单次大请求哈希计算耗时: \(String(format: "%.4f", elapsed)) 毫秒")
    }

    @Test("测试 RequestCacheKey 构造成本")
    func testRequestCacheKeyConstructionCost() throws {
        let request = TestRequest(
            userId: 1001,
            token: "test_token_abc123",
            headers: [
                "Authorization": "Bearer token123",
                "Content-Type": "application/json",
                "X-Request-ID": UUID().uuidString,
                "X-Custom-Header": "custom_value"
            ]
        )
        let mutableRequest = NtkMutableRequest(request)
        let cacheConfig = makeCacheConfig()

        print("\n=== RequestCacheKey 构造成本测试 ===")
        let iterations = 100

        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = RequestCacheKey(request: mutableRequest, cacheConfig: cacheConfig)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        print("\(iterations) 次 RequestCacheKey 构造总耗时: \(String(format: "%.4f", elapsed)) 毫秒")
        print("平均每次: \(String(format: "%.4f", elapsed / Double(iterations))) 毫秒")
    }
}

// MARK: - RequestCacheKey 实现

/// 请求缓存键
/// 用于缓存原始请求到缓存键的映射
private struct RequestCacheKey: Hashable {
    let method: String
    let baseURL: String?
    let path: String
    let headers: [String: String]?
    let parameters: [String: String]?  // 转换为字符串以支持 Hashable
    let cacheTime: TimeInterval?

    init(request: NtkMutableRequest, cacheConfig: NtkRequestConfiguration?) {
        self.method = request.method.rawValue
        self.baseURL = request.baseURL?.absoluteString
        self.path = request.path
        self.headers = cacheConfig?.filterHeaders(request.headers ?? [:])
        // 注意：这里需要转换类型为字符串以支持 Hashable
        if let params = cacheConfig?.filterParameters(request.parameters ?? [:]) {
            var convertedParams: [String: String] = [:]
            for (key, value) in params {
                convertedParams[key] = "\(value)"
            }
            self.parameters = convertedParams
        } else {
            self.parameters = nil
        }
        self.cacheTime = cacheConfig?.cacheTime
    }
}
