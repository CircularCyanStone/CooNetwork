//
//  NtkIdentityParticipation.swift
//  CooNetwork
//

/// 指定单个请求字段是否参与缓存与去重共用的本地请求身份。
///
/// 该标记只改变框架生成身份时看到的字段投影，不会删除字段，也不会改变最终发往
/// 服务端的 Header 或参数。`.automatic` 继承当前有效的请求身份策略，
/// `.included` 与 `.excluded` 则分别显式覆盖该策略；调用方应只在理解资源边界后覆盖，
/// 避免把本应区分用户或租户的请求合并为同一身份。
public enum NtkIdentityParticipation: Sendable {
    /// 继承当前有效策略，适用于没有字段级特殊规则的默认场景。
    case automatic

    /// 强制字段参与身份，适用于全局策略排除了该名称、但其实际仍区分资源、用户或租户的场景。
    case included

    /// 强制字段不参与身份，适用于 token、timestamp、nonce 等每次变化但不区分资源的动态字段。
    /// 排除凭证字段前必须用稳定参数或 identity component 保留业务主体隔离。
    case excluded
}
