//
//  NtkRequestWrapper.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

/// 请求包装器
/// 解决当用户使用enum实现iNtkRequest时无法使用存储型属性的问题
/// 提供了额外数据存储和请求对象管理功能
struct NtkRequestWrapper: Sendable {
    
    /// 包装的请求对象
    /// 只读属性，通过addRequest方法设置
    private(set) var request: iNtkRequest?
    
    /// 额外数据存储
    /// 用于在整个网络组件的调用链中传递自定义数据
    var extraData: [String: Sendable] = [:]
    
    /// 初始化空的请求包装器
    init() {
        
    }
    
    /// 下标访问额外数据
    /// 提供便捷的字典式访问方式来读写额外数据
    /// - Parameter key: 数据键
    /// - Returns: 对应的数据值，如果不存在则返回nil
    subscript(_ key: String) -> Sendable? {
        get {
            extraData[key]
        }
        
        set {
            extraData[key] = newValue
        }
    }
    
    /// 添加请求对象
    /// 设置要包装的网络请求对象
    /// - Parameter req: 网络请求对象
    mutating func addRequest(_ req: iNtkRequest) {
        request = req
    }
}
