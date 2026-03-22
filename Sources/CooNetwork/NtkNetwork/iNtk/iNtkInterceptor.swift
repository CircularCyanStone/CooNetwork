//
//  iNtkInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 拦截器优先级
///
/// 使用三层 Tier 结构控制拦截器的执行顺序，构成洋葱模型。
/// 排序规则：**Tier 优先**，同 Tier 再比 value，降序排列。
///
/// ## 执行顺序
///
/// Tier 决定层级，同 Tier 内 value 越大越靠外（请求流越先执行，响应流越晚返回）。
/// 以三层各三个拦截器为例：
///
/// **请求流**（由外到内，进入 finalHandler 前）：
/// ```
/// outer/1000 → outer/750 → outer/100
///   → standard/1000 → standard/700 → standard/300
///     → inner/1000 → inner/600 → inner/200
///       → finalHandler
/// ```
///
/// **响应流**（由内到外，finalHandler 返回后）：
/// ```
/// finalHandler
///   → inner/200 → inner/600 → inner/1000
///     → standard/300 → standard/700 → standard/1000
///       → outer/100 → outer/750 → outer/1000
/// ```
public struct NtkInterceptorPriority: Comparable, Sendable {

    /// 优先级层级（internal，不暴露给用户）
    /// outer > standard > inner，不同层级之间不可跨越
    enum Tier: Int, Comparable, Sendable {
        /// 请求流中最后执行，响应流中最先返回
        case inner = 0
        /// 请求流中居中执行，响应流中居中返回
        case standard = 1
        /// 请求流中最先执行，响应流中最后返回
        case outer = 2

        static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// 层级（internal，用户无法直接设置）
    let tier: Tier
    /// 层级内的优先级数值
    public let value: Int

    // ── 用户级别常量（standard tier）──
    /// 低优先级（250）
    public static let low    = Self(tier: .standard, value: 250)
    /// 中等优先级（750）
    public static let medium = Self(tier: .standard, value: 750)
    /// 高优先级（1000）
    public static let high   = Self(tier: .standard, value: 1000)

    // ── 框架内部常量 ──
    /// Dedup 使用：最外层
    static let outerHighest = Self(tier: .outer,    value: 1000)
    /// 外层高位
    static let outerHigh    = Self(tier: .outer,    value: 750)
    /// 外层低位
    static let outerLow     = Self(tier: .outer,    value: 250)
    
    /// 最内层
    static let innerHighest = Self(tier: .inner,    value: 1000)
    /// 内层高位
    static let innerHigh    = Self(tier: .inner,    value: 750)
    /// 内层低位
    static let innerLow     = Self(tier: .inner,    value: 250)

    /// 默认初始化：standard tier，value 750（与原行为一致）
    public init() {
        self.tier  = .standard
        self.value = 750
    }

    /// 框架内部初始化（internal）
    init(tier: Tier, value: Int) {
        self.tier  = tier
        self.value = value
    }

    /// 创建用户自定义优先级（只能创建 standard tier）
    /// - Parameter value: 优先级数值，自动 clamp 到 [0, 1000]
    public static func priority(_ value: Int) -> Self {
        .init(tier: .standard, value: max(min(value, 1000), 0))
    }

    /// 比较：先比 tier，再比 value
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
        return lhs.value < rhs.value
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tier == rhs.tier && lhs.value == rhs.value
    }
}

// MARK: - Arithmetic Operators
extension NtkInterceptorPriority {
    /// 优先级加法运算符（保持 tier，value clamp 到 [0, 1000]）
    public static func + (lhs: NtkInterceptorPriority, rhs: Int) -> NtkInterceptorPriority {
        .init(tier: lhs.tier, value: max(min(lhs.value + rhs, 1000), 0))
    }

    /// 优先级减法运算符（保持 tier，value clamp 到 [0, 1000]）
    public static func - (lhs: NtkInterceptorPriority, rhs: Int) -> NtkInterceptorPriority {
        .init(tier: lhs.tier, value: max(min(lhs.value - rhs, 1000), 0))
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
    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse
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

