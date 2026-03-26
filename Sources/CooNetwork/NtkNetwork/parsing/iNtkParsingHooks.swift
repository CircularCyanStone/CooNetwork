//
//  iNtkParsingHooks.swift
//  CooNetwork
//

import Foundation

/// 响应解析流程中的只读生命周期通知协议。
///
/// 该协议用于在 `NtkDataParsingInterceptor` 的关键里程碑触发旁路副作用，
/// 例如日志、埋点、状态同步、持久化、广播等。
///
/// 设计定位：
/// - hooks 是 observer，不是 control point
/// - hooks 负责“看见发生了什么”，而不是“决定接下来该怎么走”
/// - 主流程结果始终由 parser + policy 决定，而不是由 hook 回调决定
///
/// 运行时约束：
/// - hook 由 `NtkParsingHookDispatcher` 统一分发
/// - hook 抛错会被 dispatcher 记录并忽略，不会改写主流程 outcome
/// - 如果未来需要真正影响 outcome 的扩展点，应设计为新的主流程组件，而不是继续挂在 hooks 语义下
///
/// 事件语义：
/// - `didDecodeHeader`：decoder 已成功拿到 header 信息，可用于观测协议层返回码和消息
/// - `willValidate`：policy 已构建候选响应，准备进入业务成功判定
/// - `didValidateFail`：业务成功判定明确失败，适合做失败侧上报或记录
/// - `didComplete`：整个解析流程已形成最终成功响应，适合成功侧旁路处理
public protocol iNtkParsingHooks: Sendable {

    /// 在 decoder 成功解释出 header 信息后触发只读通知。
    ///
    /// - Parameters:
    ///   - retCode: 已解释出的业务返回码。它表示协议层 header 中的结果值，不等同于最终是否放行。
    ///   - msg: 已解释出的业务消息文本；若协议未提供则为 `nil`。
    ///   - context: 当前请求的拦截器上下文，便于 hook 关联请求侧信息或做日志补充。
    /// - Throws: 可抛错，但错误只会被 dispatcher 记录，不会改变主流程结果。
    func didDecodeHeader(
        retCode: Int,
        msg: String?,
        context: NtkInterceptorContext
    ) async throws

    /// 在 policy 已构建候选响应、即将做业务成功判定前触发只读通知。
    ///
    /// - Parameters:
    ///   - response: 已构建完成、准备进入业务判定的响应对象。它代表当前 policy 正在评估的候选结果。
    ///   - context: 当前请求的拦截器上下文。
    /// - Throws: 可抛错，但不会中断 validation 或改写最终 outcome。
    func willValidate(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async throws

    /// 在业务成功判定失败后触发只读通知。
    ///
    /// - Parameters:
    ///   - response: 已被判定为业务失败的响应对象。该对象用于观测失败现场，而不是用于恢复或吞错。
    ///   - context: 当前请求的拦截器上下文。
    /// - Throws: 可抛错，但不会替代最终将要抛出的业务失败错误。
    func didValidateFail(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async throws

    /// 在解析流程已经得到最终成功响应后触发只读通知。
    ///
    /// - Parameters:
    ///   - response: 最终成功响应。此时 policy 已完成裁决，hook 只能做旁路副作用，不能再修改结果。
    ///   - context: 当前请求的拦截器上下文。
    /// - Throws: 可抛错，但错误只用于日志/监控，不会替代成功结果返回给调用方。
    func didComplete(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async throws
}

public extension iNtkParsingHooks {
    func didDecodeHeader(retCode: Int, msg: String?, context: NtkInterceptorContext) async throws {}
    func willValidate(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {}
    func didValidateFail(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {}
    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {}
}
