//
//  iNtkCacheProvider.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/03/22.
//

import Foundation

/// 向 executor 暴露缓存读取能力，并消费框架已经确定的请求 key。
///
/// provider 不得从 request 再计算 key；同一执行路径必须与去重共享传入的 request identity。
/// request identity 是版本化但不透明的存储键，provider 可以持久化和比较其 value，不能解析其格式
/// 或将其当作鉴权信息。缓存配置无效或 key 构建失败时 executor 不会调用本协议，网络请求继续。
public protocol iNtkCacheProvider: Sendable {
    /// 按框架生成的稳定请求 key 读取缓存；存储错误可以抛出，key 构建失败不会调用此方法。
    ///
    /// request 是已完成请求修改的快照，requestIdentity 必须原样传入底层存储，不能由 provider 重新生成
    /// 第二套算法，否则缓存与去重可能对同一请求产生不同结果。
    func loadCacheData(
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async throws -> (any Sendable)?

    /// 按框架生成的稳定请求 key 查询缓存；request identity 或缓存配置不可用时 executor 直接返回 false。
    ///
    /// 该查询只描述缓存可用性，不改变网络执行；requestIdentity.value 不是凭证，provider 不得据此
    /// 推断业务字段或扩大跨 user、tenant 的缓存共享范围。
    func hasCacheData(
        for request: NtkMutableRequest,
        requestIdentity: NtkRequestIdentity
    ) async -> Bool
}
