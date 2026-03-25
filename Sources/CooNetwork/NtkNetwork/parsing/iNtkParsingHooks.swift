//
//  iNtkParsingHooks.swift
//  CooNetwork
//

import Foundation

/// 响应解析拦截器的通用生命周期钩子协议
///
/// 用于在 `NtkDataParsingInterceptor` 解析流程的关键节点观察只读里程碑。
/// 不绑定原始数据类型，可适配任意 `iNtkClient` 实现。
///
/// ## 各钩子职责
///
/// - `didDecodeHeader`：`decode()` 成功并拿到 retCode/msg 后，适合日志、埋点、状态观察
/// - `willValidate`：`NtkResponse` 构建后、业务成功判定前，适合只读观测
/// - `didValidateFail`：业务成功判定失败后触发，适合日志、埋点、错误上报
/// - `didComplete`：全流程成功后，适合埋点、持久化等旁路副作用
///
/// ## 多 hook 行为
///
/// `didDecodeHeader` / `willValidate` / `didValidateFail` / `didComplete`
/// 所有注入的 hook 均会依次执行。
///
/// ## 说明
///
/// 当前实现里 hook 抛错会继续中断主流程；但 hook 本身不负责业务裁决，
/// 不应依赖“正常返回即可吞掉错误”之类的控制流语义。
public protocol iNtkParsingHooks: Sendable {

    /// `decode()` 成功并拿到 retCode / msg 后
    func didDecodeHeader(
        retCode: Int,
        msg: String?,
        context: NtkInterceptorContext
    ) async throws

    /// NtkResponse 构建完毕、调用 validation 前
    func willValidate(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async throws

    /// 业务成功判定失败时触发
    /// 当前实现中抛错会继续传播；正常返回不会吞掉主流程错误
    func didValidateFail(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async throws

    /// 解析全流程成功后
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
