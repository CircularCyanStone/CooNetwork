//
//  iNtkInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 拦截器优先级
/// 用于管理和比较拦截器的执行优先级，支持自定义优先级数值
/// - Note: 对于请求流：值越大执行越早
///         对于响应流：值越小执行越早
public struct NtkInterceptorPriority: Comparable, Sendable {
    private(set) var value: Int

    /// 低优先级（250）
    public static let low = NtkInterceptorPriority(value: 250)
    /// 中等优先级（750）
    public static let medium = NtkInterceptorPriority(value: 750)
    /// 高优先级（1000）
    public static let high = NtkInterceptorPriority(value: 1000)

    /// 必需的初始化方法
    /// 创建默认中等优先级的实例
    public init() {
        self.value = 750
    }

    /// 创建指定数值的优先级
    /// - Parameter value: 优先级数值
    public init(value: Int) {
        self.value = value
    }

    /// 自定义优先级（限制在 high 以下）
    /// - Parameter value: 优先级数值
    /// - Returns: 新的优先级实例
    public static func priority(_ value: Int) -> Self {
        .init(value: min(value, 1000))
    }

    /// 比较两个优先级的大小
    /// - Parameters:
    ///   - lhs: 左侧优先级
    ///   - rhs: 右侧优先级
    /// - Returns: 左侧优先级是否小于右侧优先级
    public static func < (lhs: NtkInterceptorPriority, rhs: NtkInterceptorPriority) -> Bool {
        lhs.value < rhs.value
    }

    /// 判断两个优先级是否相等
    /// - Parameters:
    ///   - lhs: 左侧优先级
    ///   - rhs: 右侧优先级
    /// - Returns: 两个优先级是否相等
    public static func == (lhs: NtkInterceptorPriority, rhs: NtkInterceptorPriority) -> Bool {
        lhs.value == rhs.value
    }
}

// MARK: - Arithmetic Operators
extension NtkInterceptorPriority {
    /// 优先级加法运算符
    /// - Parameters:
    ///   - lhs: 原优先级
    ///   - rhs: 增加的数值
    /// - Returns: 新的优先级（限制在 high 以下）
    public static func + (lhs: NtkInterceptorPriority, rhs: Int) -> NtkInterceptorPriority {
        .priority(lhs.value + rhs)
    }

    /// 优先级减法运算符
    /// - Parameters:
    ///   - lhs: 原优先级
    ///   - rhs: 减少的数值
    /// - Returns: 新的优先级（限制在 low 以上）
    public static func - (lhs: NtkInterceptorPriority, rhs: Int) -> NtkInterceptorPriority {
        .priority(max(lhs.value - rhs, Self.low.value))
    }
}

/// 网络拦截器协议
/// 定义了网络请求拦截器的基本行为，支持请求和响应的拦截处理
/// 使用责任链模式，允许多个拦截器按优先级顺序处理请求
/// 因为iNtkInterceptor里面的方法是在网络组件中被调用，添加NtkActor避免隔离域的跳转。
public protocol iNtkInterceptor: Sendable {

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
    @NtkActor
    func intercept(context: NtkInterceptorContext, next: NtkRequestHandler) async throws -> any iNtkResponse
}

/// 拦截器协议的默认实现
/// 为协议方法提供默认实现，以便具体拦截器可以只实现它们关心的部分
extension iNtkInterceptor {
    /// 默认优先级为中等
    /// 大多数拦截器使用中等优先级即可满足需求
    /// - Returns: 中等优先级（750）
    public var priority: NtkInterceptorPriority {
        .medium
    }
}
