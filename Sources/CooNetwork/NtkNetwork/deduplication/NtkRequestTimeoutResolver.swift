import Foundation

/// 把请求超时和全局默认值解析成唯一、安全的实际执行超时。
///
/// timeout 不写入缓存使用的 `NtkRequestIdentity`，但同一个解析结果必须同时用于两处：
/// `NtkTaskManager` 的真实超时任务，以及 `NtkDeduplicationKey` 的隔离维度。
/// 如果两处各自回退或截断，两个请求可能被判定为可共享，却实际使用不同超时；集中解析可以
/// 保证“用于比较的 timeout”与“真正执行的 timeout”完全相同。
enum NtkRequestTimeoutResolver {
    /// 请求值与全局配置都无效时使用的框架兜底值，单位为秒。
    static let builtInDefault: TimeInterval = 20

    /// 允许的最大超时为 100 年。
    ///
    /// 上限防止任意大的 `TimeInterval` 在任务管理器换算为 UInt64 纳秒时溢出，同时保留近似
    /// “无限等待”的业务能力。所有返回路径最后都会经过该上限。
    static let maximum: TimeInterval = 3_153_600_000

    /// 按固定优先级解析有效超时。
    ///
    /// 请求值只有在有限且大于零时才生效；否则尝试 executor 创建时冻结的全局默认值；两者
    /// 都无效时回退到 20 秒。最终结果一定有限、为正且不超过 100 年，可以安全写回请求快照、
    /// 写入去重 key 并转换为纳秒执行。
    static func resolve(
        requested: TimeInterval,
        configuredDefault: TimeInterval
    ) -> TimeInterval {
        let candidate: TimeInterval
        if requested.isFinite && requested > 0 {
            candidate = requested
        } else if configuredDefault.isFinite && configuredDefault > 0 {
            candidate = configuredDefault
        } else {
            candidate = builtInDefault
        }
        return min(candidate, maximum)
    }
}
