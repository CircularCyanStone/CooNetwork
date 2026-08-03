//
//  NtkRequestIdentityPolicy.swift
//  CooNetwork
//

/// 控制哪些请求字段写入缓存与去重共用 key 的策略。
///
/// 策略只作用于本地请求 key，不会修改真正发送的 Header 或参数。排除集合与转换闭包只处理
/// 规则为 `.automatic` 的字段；字段级 `.include`/`.exclude` 始终显式覆盖策略。转换闭包必须
/// 是纯且确定的，不能读取时间、随机数或可变全局状态，否则同一请求可能得到不稳定 key。
/// 转换闭包抛错时，执行器应关闭本次缓存和去重并继续网络请求，不把 key 构建失败
/// 转换为网络错误。
///
/// 排除 `Authorization` 等凭证后，必须通过稳定字段或 request identity value 保留 user/tenant
/// 隔离，否则可能让不同主体共享缓存或去重结果。请求级非 `nil` 策略完整替换 executor 创建时
/// 冻结的全局策略，不与全局策略合并。
///
/// 一次构建的实际顺序是：先按字段 key rule 分流；再对 `.automatic` 字段执行精确名称排除；
/// 然后把剩余 automatic 字段交给转换闭包；最后把转换结果与 `.include` 字段合并。转换闭包
/// 可以删除、改写或新建 key 字段，但不能观察或覆盖显式字段。
public struct NtkRequestIdentityPolicy: Sendable {
    /// 不写入请求 key 的 Header 逻辑名称；初始化时统一转为小写以匹配 HTTP 大小写不敏感语义。
    public let excludedHeaderNames: Set<String>

    /// 不写入请求 key 的参数名称；参数键区分大小写，因此保持调用方提供的原始形式。
    public let excludedParameterNames: Set<String>

    /// 在写入请求 key 前转换剩余 `.automatic` Header 的可选闭包。
    ///
    /// 输入已经移除了 policy 名称排除项及显式 include/exclude 字段；输出随后进行 Header
    /// 合法性检查、大小写不敏感去重，并统一转成小写 key。闭包只接触请求 key 数据，不改变真实
    /// 请求，且必须保持纯函数语义。抛错时执行器仅关闭本次缓存与去重，网络请求继续执行。
    public let transformHeaders: (@Sendable ([String: String]) throws -> [String: String])?

    /// 在写入请求 key 前转换剩余 `.automatic` 参数的可选闭包。
    ///
    /// 输入已经移除了 policy 名称排除项及显式 include/exclude 字段；输出允许为嵌套结构
    /// 创建更稳定的本地表示，随后由 request identity encoder 递归编码。闭包只接触 key 数据，不改变
    /// 真实请求，且必须保持纯函数语义。抛错时执行器仅关闭本次缓存与去重，网络继续执行。
    public let transformParameters: (@Sendable ([String: Sendable]) throws -> [String: Sendable])?

    /// 创建请求 key 策略。
    ///
    /// Header 排除名会被统一小写，参数排除名保持原样；默认不排除，也不转换任何字段。
    /// 请求级实例一旦提供就完整替换全局策略。若排除鉴权字段，调用方必须额外保留稳定的
    /// 主体隔离字段。转换闭包必须纯且确定，抛错时由执行器关闭本次缓存和去重并继续网络。
    /// - Parameters:
    ///   - excludedHeaderNames: 不写入请求 key 的 `.automatic` Header 逻辑名称。
    ///   - excludedParameterNames: 不写入请求 key 的 `.automatic` 参数精确名称。
    ///   - transformHeaders: 写入 key 前的 Header 转换闭包。
    ///   - transformParameters: 写入 key 前的参数转换闭包。
    public init(
        excludedHeaderNames: Set<String> = [],
        excludedParameterNames: Set<String> = [],
        transformHeaders: (@Sendable ([String: String]) throws -> [String: String])? = nil,
        transformParameters: (@Sendable ([String: Sendable]) throws -> [String: Sendable])? = nil
    ) {
        // Header 的排除匹配必须遵循 HTTP 字段名大小写不敏感语义，因此在策略创建时一次性
        // 统一转成小写；参数是业务 payload，保持原字符串才能区分 token、Token 等不同参数。
        self.excludedHeaderNames = Set(excludedHeaderNames.map { $0.lowercased() })
        self.excludedParameterNames = excludedParameterNames
        self.transformHeaders = transformHeaders
        self.transformParameters = transformParameters
    }

    /// 严格策略：所有未被字段级显式排除的 Header 与参数都写入请求 key。
    ///
    /// 这是防止跨 user/tenant 错误共享的安全默认值；它不改变真实请求，也不会因字段动态
    /// 变化而自动放宽。应用应在启动阶段显式声明确认安全的公共动态字段。
    public static let strict = Self()
}
