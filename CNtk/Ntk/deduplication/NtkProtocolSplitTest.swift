//
//  NtkProtocolSplitTest.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//  Copyright © 2024 coo. All rights reserved.
//

import Foundation

/// 测试新的协议拆分功能
class NtkProtocolSplitTest {
    
    /// 测试新的 iNtkParameterFilter 协议
    func testParameterFilter() {
        let filter = TestParameterFilter()
        
        // 测试请求头过滤
        let headers = [
            "Content-Type": "application/json",
            "X-Request-ID": "12345",
            "Authorization": "Bearer token"
        ]
        let filteredHeaders = filter.filterHeaders(headers)
        print("原始请求头: \(headers)")
        print("过滤后请求头: \(filteredHeaders)")
        
        // 测试请求参数过滤
        let parameters: [String: Sendable] = [
            "userId": "user123",
            "timestamp": 1703001234,
            "data": "important data"
        ]
        let filteredParameters = filter.filterParameters(parameters)
        print("原始参数: \(parameters)")
        print("过滤后参数: \(filteredParameters)")
    }
    
    /// 测试新的缓存策略
    func testNewCachePolicy() {
        let policy = TestRequestPolicy()
        
        // 测试缓存时间
        print("缓存时间: \(policy.cacheTime)秒")
        
        // 测试请求头过滤
        let headers = [
            "Content-Type": "application/json",
            "X-Timestamp": "1703001234"
        ]
        let filteredHeaders = policy.filterHeaders(headers)
        print("缓存策略过滤后的请求头: \(filteredHeaders)")
        
        // 测试参数过滤
        let parameters: [String: Sendable] = [
            "query": "search term",
            "nonce": "random123"
        ]
        let filteredParameters = policy.filterParameters(parameters)
        print("缓存策略过滤后的参数: \(filteredParameters)")
    }
    
    /// 测试向后兼容性
    func testBackwardCompatibility() {
        let legacyPolicy = LegacyRequestPolicy()
        
        // 测试旧的 filterParameter 方法
        let parameters: [String: Sendable] = [
            "data": "test",
            "timestamp": 1703001234
        ]
        let filteredParameters = legacyPolicy.filterParameter(parameters)
        print("向后兼容过滤结果: \(filteredParameters)")
        
        // 验证新方法也能工作
        let newFilteredParameters = legacyPolicy.filterParameters(parameters)
        print("新方法过滤结果: \(newFilteredParameters)")
    }
}

// MARK: - 测试实现

/// 测试参数过滤器实现
struct TestParameterFilter: iNtkParameterFilter {
    func filterHeaders(_ headers: [String: String]) -> [String: String] {
        // 过滤掉动态请求头
        return headers.filter { key, _ in
            !["X-Request-ID", "X-Timestamp"].contains(key)
        }
    }
    
    func filterParameters(_ parameters: [String: Sendable]) -> [String: Sendable] {
        // 过滤掉时间戳参数
        return parameters.filter { key, _ in
            !["timestamp", "nonce"].contains(key)
        }
    }
}

/// 测试缓存策略实现
struct TestRequestPolicy: iNtkRequestConfiguration {
    var cacheTime: TimeInterval {
        return 300 // 5分钟
    }
    
    func filterHeaders(_ headers: [String: String]) -> [String: String] {
        // 过滤掉时间戳相关的请求头
        return headers.filter { key, _ in
            !key.contains("Timestamp")
        }
    }
    
    func filterParameters(_ parameters: [String: Sendable]) -> [String: Sendable] {
        // 过滤掉随机数参数
        return parameters.filter { key, _ in
            key != "nonce"
        }
    }
}

/// 向后兼容的缓存策略实现
struct LegacyRequestPolicy: iNtkRequestConfiguration {
    var cacheTime: TimeInterval {
        return 600 // 10分钟
    }
    
    // 只实现旧的 filterParameter 方法，新方法会自动调用它
    func filterParameter(_ parameter: [String: Sendable]) -> [String: Sendable] {
        return parameter.filter { key, _ in
            key != "timestamp"
        }
    }
}