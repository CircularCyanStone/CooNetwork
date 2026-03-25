//
//  iNtkParsingHooks.swift
//  CooNetwork
//

import Foundation

/// 响应解析拦截器的生命周期通知协议。
///
/// 用于在 `NtkDataParsingInterceptor` 解析流程的关键节点发送只读通知。
///
/// ## 当前约定
///
/// - `iNtkParsingHooks` 只用于表达解析流程中的生命周期通知
/// - hook 不参与业务裁决，不能作为结果判定入口
/// - 在当前实现中，hook 由 dispatcher 负责分发；hook 错误不会改变主流程结果，主流程仍由 parser 与 policy 决定
/// - hooks 的职责仅限生命周期通知，不承载结果判定语义
///
/// ## 各 hook 职责
///
/// - `didDecodeHeader`：`decode()` 成功并拿到 retCode/msg 后，适合日志、埋点、状态观察
/// - `willValidate`：`NtkResponse` 构建后、业务成功判定前，适合只读观测
/// - `didValidateFail`：业务成功判定失败后触发，适合日志、埋点、错误上报
/// - `didComplete`：全流程成功后，适合日志、埋点等旁路处理
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
