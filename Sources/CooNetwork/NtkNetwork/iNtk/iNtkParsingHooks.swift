//
//  iNtkParsingHooks.swift
//  CooNetwork
//

import Foundation

/// 响应解析拦截器的通用生命周期钩子协议
///
/// 用于在 `NtkDataParsingInterceptor` 解析流程的关键节点注入自定义逻辑。
/// 不绑定原始数据类型，可适配任意 `iNtkClient` 实现。
///
/// ## 各钩子职责
///
/// - `didDecodeHeader`：retCode/msg 提取后，适合 token 过期判断、retcode 语义映射
/// - `willValidate`：`NtkResponse` 构建后、`validation` 调用前，适合额外字段校验
/// - `didValidateFail`：`isServiceSuccess` 返回 false 时，适合错误恢复或本地化
/// - `didComplete`：全流程成功后，适合埋点、token 存储等副作用
///
/// ## 多 hook 行为
///
/// `didDecodeHeader` / `willValidate` / `didValidateFail` / `didComplete`
/// 所有注入的 hook 均会依次执行（观察者语义）。
public protocol iNtkParsingHooks: Sendable {

    /// retCode / msg 解码完成后
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

    /// isServiceSuccess 返回 false 时
    /// 抛出则继续传播错误；正常返回则吞掉错误（谨慎使用）
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
