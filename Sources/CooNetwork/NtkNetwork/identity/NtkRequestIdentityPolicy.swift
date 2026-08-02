//
//  NtkRequestIdentityPolicy.swift
//  CooNetwork
//

/// 控制缓存键与去重键如何投影请求字段的策略。
///
/// 策略只作用于本地请求身份，不会修改真正发送的 Header 或参数。排除集合与 normalizer
/// 只处理参与状态为 `.automatic` 的字段；字段级 `.included`/`.excluded` 始终显式覆盖策略。
/// normalizer 必须是纯且确定的，不能读取时间、随机数或可变全局状态，否则同一请求可能得到
/// 不稳定身份。normalizer 抛错时，执行器应关闭本次缓存和去重并继续网络请求，不把身份失败
/// 转换为网络错误。
///
/// 排除 `Authorization` 等凭证后，必须通过稳定字段或 identity component 保留 user/tenant
/// 隔离，否则可能让不同主体共享缓存或去重结果。请求级非 `nil` 策略完整替换 executor 创建时
/// 冻结的全局策略，不与全局策略合并。
public struct NtkRequestIdentityPolicy: Sendable {
    /// 不参与本地身份的 Header 逻辑名称；初始化时统一转为小写以匹配 HTTP 大小写不敏感语义。
    public let excludedHeaderNames: Set<String>

    /// 不参与本地身份的参数名称；参数键区分大小写，因此保持调用方提供的原始形式。
    public let excludedParameterNames: Set<String>

    /// 对剩余 `.automatic` Header 进行确定性规范化的可选闭包。
    ///
    /// 闭包只接触身份投影，不改变真实请求，且必须保持纯函数语义。抛错时本次缓存与去重
    /// 应降级为关闭，网络请求继续执行。
    public let normalizeHeaders: (@Sendable ([String: String]) throws -> [String: String])?

    /// 对剩余 `.automatic` 参数进行确定性规范化的可选闭包。
    ///
    /// 闭包只接触身份投影，不改变真实请求，且必须保持纯函数语义。抛错时本次缓存与去重
    /// 应降级为关闭，网络请求继续执行。
    public let normalizeParameters: (@Sendable ([String: Sendable]) throws -> [String: Sendable])?

    /// 创建请求身份策略。
    ///
    /// Header 排除名会被统一小写，参数排除名保持原样；默认不排除或规范化任何字段。
    /// 请求级实例一旦提供就完整替换全局策略。若排除鉴权字段，调用方必须额外保留稳定的
    /// 主体隔离字段。normalizer 必须纯且确定，抛错时由执行器关闭本次缓存和去重并继续网络。
    /// - Parameters:
    ///   - excludedHeaderNames: 需要从 `.automatic` Header 身份投影中排除的逻辑名称。
    ///   - excludedParameterNames: 需要从 `.automatic` 参数身份投影中排除的精确名称。
    ///   - normalizeHeaders: 可选的 Header 身份规范化闭包。
    ///   - normalizeParameters: 可选的参数身份规范化闭包。
    public init(
        excludedHeaderNames: Set<String> = [],
        excludedParameterNames: Set<String> = [],
        normalizeHeaders: (@Sendable ([String: String]) throws -> [String: String])? = nil,
        normalizeParameters: (@Sendable ([String: Sendable]) throws -> [String: Sendable])? = nil
    ) {
        self.excludedHeaderNames = Set(excludedHeaderNames.map { $0.lowercased() })
        self.excludedParameterNames = excludedParameterNames
        self.normalizeHeaders = normalizeHeaders
        self.normalizeParameters = normalizeParameters
    }

    /// 严格策略：所有未被字段级显式排除的 Header 与参数都参与身份。
    ///
    /// 这是防止跨 user/tenant 错误共享的安全默认值；它不规范化真实请求，也不会因字段动态
    /// 变化而自动放宽。应用应在启动阶段显式声明确认安全的公共动态字段。
    public static let strict = Self()
}
