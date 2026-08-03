/// 框架根据最终请求投影生成的稳定身份。
///
/// 自定义缓存 provider 可以存储和比较该值，但不能自行构造或解析 digest。
/// 算法升级会改变前缀和内容，旧缓存由现有淘汰策略自然清理。
public struct NtkRequestIdentity: Hashable, Sendable {
    /// 包含算法版本的持久化缓存键；它不是业务字段，也不应作为鉴权凭证。
    public let digest: String

    init(digest: String) {
        self.digest = digest
    }
}
