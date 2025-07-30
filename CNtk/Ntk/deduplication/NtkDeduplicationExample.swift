//
//  NtkDeduplicationExample.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//  Copyright © 2024 coo. All rights reserved.
//

import Foundation

/// 网络请求去重示例
@NtkActor
class NtkDeduplicationExample {
    
    /// 演示基本的请求去重功能
    /// 相同的请求在短时间内只会执行一次，后续请求会复用第一次的结果
    func demonstrateBasicDeduplication() async {
        print("=== 基本请求去重示例 ===")
        
        // 创建三个相同的请求
        let request1 = SampleRequest()
        let request2 = SampleRequest()
        let request3 = SampleRequest()
        
        print("发起三个相同的请求...")
        
        // 同时发起三个请求，由于去重机制，实际只会执行一次网络请求
        async let task1 = makeRequest(request1)
        async let task2 = makeRequest(request2)
        async let task3 = makeRequest(request3)
        
        // 等待所有请求完成
        let results = await [task1, task2, task3]
        
        print("请求完成，结果数量: \(results.count)")
        print("所有请求都应该返回相同的结果（由于去重机制）")
    }
    
    /// 演示带参数的请求去重
    /// 不同参数的请求会被视为不同的请求，不会被去重
    func demonstrateParameterizedDeduplication() async {
        print("\n=== 带参数的请求去重示例 ===")
        
        // 创建不同参数的请求
        let request1 = GetUserInfoRequest(userId: "user123")
        let request2 = GetUserInfoRequest(userId: "user123") // 相同参数
        let request3 = GetUserInfoRequest(userId: "user456") // 不同参数
        
        print("发起带参数的请求...")
        
        // 同时发起请求
        async let task1 = makeRequest(request1)
        async let task2 = makeRequest(request2) // 会被去重
        async let task3 = makeRequest(request3) // 不会被去重
        
        let results = await [task1, task2, task3]
        
        print("请求完成，结果数量: \(results.count)")
        print("相同参数的请求被去重，不同参数的请求独立执行")
    }
    
    /// 演示动态参数过滤
    /// 某些参数（如时间戳）不参与去重判断
    func demonstrateDynamicParameterFiltering() async {
        print("\n=== 动态参数过滤示例 ===")
        
        // 创建带有动态参数的请求
        let request1 = DynamicRequest(data: "test", timestamp: Date().timeIntervalSince1970)
        let request2 = DynamicRequest(data: "test", timestamp: Date().timeIntervalSince1970 + 1)
        
        print("发起带动态参数的请求...")
        print("虽然时间戳不同，但由于过滤策略，这两个请求会被去重")
        
        async let task1 = makeRequest(request1)
        async let task2 = makeRequest(request2)
        
        let results = await [task1, task2]
        
        print("请求完成，结果数量: \(results.count)")
        print("动态参数被过滤，请求被成功去重")
    }
    
    /// 演示缓存策略配置
    /// 展示如何配置不同的缓存和去重策略
    func demonstrateRequestPolicy() async {
        print("\n=== 缓存策略配置示例 ===")
        
        let request = ConfigurableRequest()
        
        print("使用自定义缓存策略的请求...")
        
        let result = await makeRequest(request)
        
        print("请求完成，缓存策略生效")
        print("请求头和参数根据策略进行了过滤")
    }
    
    /// 模拟网络请求
    private func makeRequest<T: iNtkRequest>(_ request: T) async -> String {
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        return "Response for \(type(of: request))"
    }
}

// MARK: - 示例请求类型

/// 简单的示例请求
struct SampleRequest: iNtkRequest {
    var method: NtkHTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/sample" }
    
    // 使用新的缓存策略，分别配置请求头和参数过滤
    var requestPolicy: (any iNtkRequestConfiguration)? {
        NtkDefaultRequestConfiguration(
            cacheTime: 300,
            filterHeaders: { headers in
                // 过滤掉动态请求头
                headers.filter { key, _ in
                    !["X-Request-ID", "X-Timestamp"].contains(key)
                }
            },
            filterParameters: { parameters in
                // 过滤掉时间戳参数
                parameters.filter { key, _ in
                    key != "timestamp"
                }
            }
        )
    }
}

/// 带用户ID参数的请求
struct GetUserInfoRequest: iNtkRequest {
    let userId: String
    
    var method: NtkHTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/user/\(userId)" }
    
    var parameters: [String: Sendable]? {
        ["userId": userId]
    }
}

/// 带动态参数的请求
struct DynamicRequest: iNtkRequest {
    let data: String
    let timestamp: TimeInterval
    
    var method: NtkHTTPMethod { .post }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/dynamic" }
    
    var parameters: [String: Sendable]? {
        [
            "data": data,
            "timestamp": timestamp
        ]
    }
    
    // 配置过滤策略，时间戳不参与去重
    var requestPolicy: (any iNtkRequestConfiguration)? {
        NtkDefaultRequestConfiguration(
            cacheTime: 60,
            filterParameters: { parameters in
                parameters.filter { key, _ in
                    key != "timestamp"
                }
            }
        )
    }
}

/// 可配置的请求示例
struct ConfigurableRequest: iNtkRequest {
    var method: NtkHTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/configurable" }
    
    var headers: [String: String]? {
        [
            "Content-Type": "application/json",
            "X-Request-ID": UUID().uuidString,
            "X-Timestamp": "\(Date().timeIntervalSince1970)"
        ]
    }
    
    var parameters: [String: Sendable]? {
        [
            "query": "search term",
            "nonce": UUID().uuidString
        ]
    }
    
    // 使用新的过滤方法
    var requestPolicy: (any iNtkRequestConfiguration)? {
        NtkDefaultRequestConfiguration(
            cacheTime: 600,
            filterHeaders: { headers in
                // 过滤掉动态请求头
                headers.filter { key, _ in
                    !key.hasPrefix("X-")
                }
            },
            filterParameters: { parameters in
                // 过滤掉随机数参数
                parameters.filter { key, _ in
                    key != "nonce"
                }
            }
        )
    }
}

// MARK: - 使用示例

/// 运行所有示例
@NtkActor
func runDeduplicationExamples() async {
    let example = NtkDeduplicationExample()
    
    await example.demonstrateBasicDeduplication()
    await example.demonstrateParameterizedDeduplication()
    await example.demonstrateDynamicParameterFiltering()
    await example.demonstrateRequestPolicy()
    
    print("\n=== 所有示例运行完成 ===")
}
