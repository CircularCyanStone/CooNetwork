//
//  iNtkInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 拦截器优先级枚举
/// 定义了拦截器的执行优先级，数值越大优先级越高
enum iNtkInterceptorPriority: Int {
    /// 低优先级（250）
    case low    = 250
    /// 中等优先级（750）
    case medium = 750
    /// 高优先级（1000）
    case high   = 1000
}

/// Int类型的优先级扩展
/// 提供便捷的优先级常量访问，简化优先级值的使用
extension Int {
    /// 低优先级值（250）
    static let low: Int = iNtkInterceptorPriority.low.rawValue
    /// 中等优先级值（750）
    static let medium: Int = iNtkInterceptorPriority.medium.rawValue
    /// 高优先级值（1000）
    static let high: Int = iNtkInterceptorPriority.high.rawValue
}

/// 拦截器优先级类
/// 用于管理和比较拦截器的执行优先级，支持自定义优先级数值
class NtkInterceptorPriority: Comparable {
    /// 优先级数值，默认为中等优先级（750）
    private(set) var value: Int = .medium
    
    /// 必需的初始化方法
    /// 创建默认中等优先级的实例
    required
    init() {
        
    }
    
    /// 创建指定优先级的实例
    /// - Parameter value: 优先级数值，会被限制在最高优先级（1000）以内
    /// - Returns: 新的优先级实例
    class func priority(_ value: Int) -> Self {
        var pValue: Int = value
        if pValue > .high {
            pValue = .high
        }
        let p = self.init()
        p.value = pValue
        return p
    }
    
    /// 比较两个优先级的大小
    /// - Parameters:
    ///   - lhs: 左侧优先级
    ///   - rhs: 右侧优先级
    /// - Returns: 左侧优先级是否小于右侧优先级
    static func < (lhs: NtkInterceptorPriority, rhs: NtkInterceptorPriority) -> Bool {
        return lhs.value < rhs.value
    }

    /// 判断两个优先级是否相等
    /// - Parameters:
    ///   - lhs: 左侧优先级
    ///   - rhs: 右侧优先级
    /// - Returns: 两个优先级是否相等
    static func == (lhs: NtkInterceptorPriority, rhs: NtkInterceptorPriority) -> Bool {
        return lhs.value == rhs.value
    }
}


/// 网络拦截器协议
/// 定义了网络请求拦截器的基本行为，支持请求和响应的拦截处理
/// 使用责任链模式，允许多个拦截器按优先级顺序处理请求
/// 因为iNtkInterceptor里面的方法是在网络组件中被调用，添加NtkActor避免隔离域的跳转。
@NtkActor
protocol iNtkInterceptor: Sendable {
    
    /// 拦截器优先级
    /// 默认为中等优先级，用于控制拦截器的执行顺序
    /// - Note: 对于请求流：值越大执行越早
    ///         对于响应流：值越小执行越早
    /// - Returns: 拦截器的执行优先级
    var priority: NtkInterceptorPriority { get }
    
    /// 拦截网络请求
    /// 在请求执行过程中被调用，可以修改请求、处理响应或执行其他逻辑
    /// - Parameters:
    ///   - context: 请求上下文，包含请求信息和客户端实例
    ///   - next: 下一个请求处理器，用于继续执行责任链
    /// - Returns: 处理后的响应对象
    /// - Throws: 拦截过程中的错误
    func intercept(context: NtkRequestContext, next: NtkRequestHandler) async throws -> any iNtkResponse
    
    /// 错误重试判断方法（可选）
    /// 在请求失败时调用，判断是否需要重试以及重试策略
    /// - Parameters:
    ///   - error: 导致请求失败的错误
    ///   - request: 原始请求对象
    ///   - retryCount: 当前已重试的次数
    /// - Returns: 元组(shouldRetry: Bool, delay: TimeInterval?) 指示是否重试以及重试前的延迟时间
    func shouldRetry(error: Error, for request: iNtkRequest, retryCount: Int) -> (Bool, TimeInterval?)
}

/// 拦截器协议的默认实现
/// 为协议方法提供默认实现，以便具体拦截器可以只实现它们关心的部分
extension iNtkInterceptor {
    /// 默认优先级为中等
    /// 大多数拦截器使用中等优先级即可满足需求
    /// - Returns: 中等优先级（750）
    var priority: NtkInterceptorPriority {
        .priority(.medium)
    }
    
    /// 默认不重试
    /// 默认情况下拦截器不处理重试逻辑，由具体实现决定
    /// - Parameters:
    ///   - error: 请求错误
    ///   - request: 原始请求
    ///   - retryCount: 重试次数
    /// - Returns: 不重试，延迟为nil
    func shouldRetry(error: Error, for request: iNtkRequest, retryCount: Int) -> (Bool, TimeInterval?) {
        (false, nil)
    }
}
