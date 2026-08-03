import Foundation

enum NtkEffectiveTimeoutResolver {
    static let builtInDefault: TimeInterval = 20
    static let maximum: TimeInterval = 3_153_600_000

    static func resolve(
        requested: TimeInterval,
        configuredDefault: TimeInterval
    ) -> TimeInterval {
        // 优先使用请求值，其次使用配置默认值，最后回退到内建值。
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
