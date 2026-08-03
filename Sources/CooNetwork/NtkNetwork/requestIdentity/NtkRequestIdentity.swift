/// 框架根据最终请求内容生成的稳定 key。
///
/// “最终请求内容”指请求修改器执行完毕后，按照字段 key rule、有效 policy 和本地
/// request identity value 过滤出的资源描述。它不是原始 request 的序列化结果，也不包含缓存
/// 时长、响应类型、超时或去重 namespace。
///
/// 同一执行路径会把该值同时交给缓存与去重：缓存直接使用 `value`；去重则在它之外继续
/// 加入响应类型、有效超时和 namespace。这样缓存只回答“是不是同一资源”，去重则回答
/// “整条执行流水线能不能共享同一个结果”。
///
/// 自定义缓存 provider 可以存储和比较该值，但不能自行构造或解析 value。算法升级会改变
/// 版本前缀和内容，使旧缓存自然不可达，再由存储既有淘汰策略清理。
public struct NtkRequestIdentity: Hashable, Sendable {
    /// 包含算法版本的持久化缓存键。
    ///
    /// 当前格式仍是历史前缀 `ntk-identity-v2-` 加 64 位小写 SHA-256，以继续命中重命名前
    /// 已落盘的缓存。调用方只能把它当作不透明 key 使用；它不是业务 ID、设备 ID 或鉴权凭证，
    /// 也不能依赖其前缀和内部格式反推字段。
    public let value: String

    /// 只有框架 request identity builder 可以创建该值，防止缓存 provider 自制第二套 key。
    init(value: String) {
        self.value = value
    }
}
