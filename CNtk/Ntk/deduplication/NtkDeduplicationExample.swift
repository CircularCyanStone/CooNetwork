//
//  NtkDeduplicationExample.swift
//  CNtk
//
//  Created by Trae Builder on 2024/12/19.
//

import Foundation

/// 请求去重功能使用示例
/// 展示如何在实际项目中使用集成了去重功能的NtkNetwork
@NtkActor
class NtkDeduplicationExample {
    
    // MARK: - 基本使用示例
    
    /// 示例1: 使用NtkNetwork发送请求（自动启用去重）
    /// NtkNetwork现在自动集成了去重功能，无需手动配置
    func exampleBasicUsage() async {
        // 创建网络客户端和请求
        // let client = YourNetworkClient() // 实现iNtkClient协议
        // let request = YourApiRequest() // 实现iNtkRequest协议
        // let dataParser = YourDataParser() // 实现iNtkInterceptor协议
        // let validation = YourValidation() // 实现iNtkResponseValidation协议
        
        // 创建NtkNetwork实例 - 去重功能自动启用
        // let network = NtkNetwork(client, request: request, dataParsingInterceptor: dataParser, validation: validation)
        
        // 发送请求 - 如果有相同请求正在进行，会自动去重并共享结果
        // let response = await network.sendRequest()
    }
    
    /// 示例2: 禁用特定请求的去重功能
    func exampleDisableDeduplication() {
        // 如果需要禁用特定请求的去重功能，可以在请求对象中设置
        // let request = YourApiRequest()
        // request.disableDeduplication() // 在请求级别禁用去重
        
        // 或者通过NtkRequestWrapper设置
        var wrapper = NtkRequestWrapper()
        // wrapper.addRequest(request)
        wrapper.disableDeduplication()
    }
    
    /// 示例3: 全局配置去重功能
    func exampleGlobalConfiguration() {
        // 全局禁用去重功能
        NtkDeduplicationConfig.shared.isGloballyEnabled = false
    }
    
    // MARK: - 配置示例
    
    /// 示例4: 详细配置选项
    func exampleDetailedConfiguration() {
        let config = NtkDeduplicationConfig.shared
        
        // 启用调试日志
        config.isDebugLoggingEnabled = true
        
        // 添加自定义动态Header
        config.addDynamicHeader("x-custom-timestamp")
        
        // 全局禁用去重功能
        config.isGloballyEnabled = false
    }
    
    /// 示例5: 动态Header管理
    func exampleDynamicHeaderManagement() {
        let config = NtkDeduplicationConfig.shared
        
        // 添加需要忽略的动态Header
        config.addDynamicHeader("x-session-id")
        config.addDynamicHeader("x-device-id")
        
        // 检查Header是否为动态Header
        if config.isDynamicHeader("timestamp") {
            print("timestamp是动态Header，在去重时会被忽略")
        }
        
        // 移除动态Header
        config.removeDynamicHeader("authorization")
    }
    
    // MARK: - 实际场景示例
    
    /// 示例6: 用户信息请求去重
    func exampleUserInfoDeduplication() async {
        // 模拟多个地方同时请求用户信息
        async let userInfo1 = fetchUserInfo(enableDeduplication: true)
        async let userInfo2 = fetchUserInfo(enableDeduplication: true)
        async let userInfo3 = fetchUserInfo(enableDeduplication: true)
        
        do {
            // 这三个请求会被去重，只发送一次网络请求
            let results = try await [userInfo1, userInfo2, userInfo3]
            print("获取到用户信息: \(results)")
        } catch {
            print("请求失败: \(error)")
        }
    }
    
    /// 示例7: 列表数据请求去重
    func exampleListDataDeduplication() async {
        // 启用调试日志以观察去重效果
        NtkDeduplicationConfig.shared.isDebugLoggingEnabled = true
        
        // 模拟快速连续的列表请求
        for i in 1...5 {
            Task {
                do {
                    let data = try await fetchListData(page: 1, enableDeduplication: true)
                    print("请求\(i)完成: \(data.count)条数据")
                } catch {
                    print("请求\(i)失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func fetchUserInfo(enableDeduplication: Bool) async throws -> ExampleUserInfo {
        let request = GetUserInfoRequest()
        var wrapper = NtkRequestWrapper()
        wrapper.addRequest(request)
        
        if enableDeduplication {
            wrapper.enableDeduplication()
        }
        
        // 这里应该调用实际的网络客户端
        // return try await client.send(wrapper)
        
        // 模拟返回
        return ExampleUserInfo(id: "123", name: "Test User")
    }
    
    private func fetchListData(page: Int, enableDeduplication: Bool) async throws -> [ListItem] {
        let request = GetListDataRequest(page: page)
        var wrapper = NtkRequestWrapper()
        wrapper.addRequest(request)
        
        if enableDeduplication {
            wrapper.enableDeduplication()
        }
        
        // 这里应该调用实际的网络客户端
        // return try await client.send(wrapper)
        
        // 模拟返回
        return [ListItem(id: "1", title: "Item 1")]
    }
}

// MARK: - 示例数据模型

struct ExampleUserInfo {
    let id: String
    let name: String
}

struct ListItem {
    let id: String
    let title: String
}

// MARK: - 示例请求

struct GetUserInfoRequest: iNtkRequest {
    var method: NtkHTTPMethod { .get }
    var path: String { "/api/user/info" }
    var parameters: [String: Sendable]? { nil }
    var headers: [String: String]? { nil }
}

struct GetListDataRequest: iNtkRequest {
    let page: Int
    
    var method: NtkHTTPMethod { .get }
    var path: String { "/api/list" }
    var parameters: [String: Sendable]? { ["page": page] }
    var headers: [String: String]? { nil }
}

// MARK: - 使用建议

/*
 使用建议:
 
 1. 适合去重的场景:
    - 用户信息、配置信息等相对静态的数据请求
    - 列表数据的首页请求
    - 搜索建议、自动完成等频繁触发的请求
    - 重复点击按钮导致的重复请求
 
 2. 不适合去重的场景:
    - 提交表单、创建数据等写操作
    - 包含时间戳等动态参数的请求
    - 需要实时数据的请求
    - 文件上传、下载等大数据传输
 
 3. 配置建议:
    - 在开发和测试阶段启用调试日志
    - 根据应用特点调整超时时间和并发数限制
    - 合理配置动态Header黑名单
    - 在性能敏感的场景中谨慎使用
 
 4. 监控和调试:
    - 使用NtkDeduplicationLogger观察去重效果
    - 监控内存使用情况，避免请求积压
    - 定期检查配置是否合理
 */
