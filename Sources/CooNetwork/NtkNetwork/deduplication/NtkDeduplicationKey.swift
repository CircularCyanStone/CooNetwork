import Foundation

/// 判断两个正在执行的网络流水线能否共享同一个底层 Task。
///
/// `requestIdentity` 只证明两次请求指向同一资源；去重位于拦截器链最外层，实际共享的还包括
/// client、解析和响应结果，所以必须额外隔离返回类型、真实超时和由调用方声明的流水线
/// namespace。该类型直接使用结构化 `Hashable` 字段，不做字符串拼接，避免分隔符碰撞和类型名
/// 描述不稳定。
struct NtkDeduplicationKey: Hashable, Sendable {
    /// method、baseURL、path、筛选后的 Header/参数和本地附加值共同生成的资源 key。
    let requestIdentity: NtkRequestIdentity

    /// 当前泛型 `ResponseData` 的进程内精确类型标识，防止不同解析结果发生强制类型转换共享。
    let responseType: ObjectIdentifier

    /// 与真实 timeout task 使用的同一个有效值；它已经完成无效值回退和最大值截断。
    /// 两个调用的超时承诺不同时必须生成不同去重 key，不能由先创建任务的一方决定另一方的超时。
    let effectiveTimeout: TimeInterval

    /// 调用方声明的执行流水线边界；不同 client、parser、retry/validation 语义应使用不同值。
    let namespace: String
}
