//
//  NtkRequestIdentityRule.swift
//  CooNetwork
//

/// 指定单个请求字段是否写入缓存与去重共用的请求 key。
///
/// 该规则只改变框架生成请求 key 时使用的字段，不会删除字段，也不会改变最终发往
/// 服务端的 Header 或参数。`.automatic` 继承当前有效的请求 key 策略，
/// `.include` 与 `.exclude` 则分别显式覆盖该策略；调用方应只在理解资源边界后覆盖，
/// 避免把本应区分用户或租户的请求合并为同一个 key。
///
/// 运行时，字段会在请求修改器全部完成后由 `NtkRequestIdentityBuilder` 分类。只有
/// `.automatic` 字段会进入名称排除集合和自定义转换闭包；显式 include/exclude
/// 字段会绕过转换闭包，保证局部规则不会被全局策略再次解释。
public enum NtkRequestIdentityRule: Sendable {
    /// 继承当前有效策略。
    ///
    /// 该字段先接受 policy 的精确名称排除，再与其他 automatic 字段一起传给转换闭包。
    /// 转换后的值才会写入 key；因此 automatic 不等于“一定写入”，而是把决定权
    /// 交给本次 executor 已冻结的 policy。
    case automatic

    /// 强制把字段写入请求 key。
    ///
    /// 该字段不会交给转换闭包，即使全局排除了同名字段也仍会原样写入 key。它用于特殊接口
    /// 重新纳入会改变资源或主体边界的字段；若转换闭包另外生成同名字段，框架会把它判定为
    /// key 冲突并关闭本次缓存与去重，而不会猜测哪一个值优先。
    case include

    /// 强制不把字段写入请求 key。
    ///
    /// 字段仍完整发送给服务器，但不会交给转换闭包，也不会进入 key。适用于 timestamp、
    /// nonce 等每次变化却不改变资源的字段。排除 token、Authorization 等凭证前必须用稳定
    /// 参数或 request identity value 补回 user/tenant 隔离，否则不同主体可能命中同一缓存或
    /// 共享同一个正在执行的请求。
    case exclude
}
