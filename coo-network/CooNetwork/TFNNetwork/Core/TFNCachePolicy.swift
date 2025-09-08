import Foundation

/// TFN缓存策略结构体
struct TFNCachePolicy: Sendable {
    let duration: TimeInterval
    let filterParameter: @Sendable (_ parameters: [String: Sendable]?) -> [String: Sendable]?
    let shouldCache: @Sendable (any iTFNRequest) -> Bool
    
    static func `default`(duration: TimeInterval) -> TFNCachePolicy {
        return TFNCachePolicy(
            duration: duration,
            filterParameter: { parameters in
                return parameters
            },
            shouldCache: { _ in true }
        )
    }
}
