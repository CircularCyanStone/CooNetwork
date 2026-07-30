import Foundation

/// 响应解析扩展点使用的只读请求上下文快照。
///
/// 该值在 `NtkActor` 隔离域内从拦截器上下文创建，随后传递给非隔离的
/// transformer、decoder、hooks 与 parsing policy。它不暴露网络 client，
/// 也不允许扩展点修改拦截器链中的共享状态。
///
/// 这是结构值快照，不会对 `Sendable` 容器中可能存在的引用值做通用深拷贝。
public struct NtkParsingContext: Sendable {
    /// 进入响应解析阶段时的请求值快照。
    public let request: NtkMutableRequest

    /// 进入响应解析阶段时的拦截器共享数据快照。
    public let extraData: [String: any Sendable]

    /// 创建解析阶段使用的只读结构快照。
    ///
    /// - Parameters:
    ///   - request: 进入解析阶段时的可变请求值副本。
    ///   - extraData: 进入解析阶段时的拦截器共享数据字典副本。
    public init(
        request: NtkMutableRequest,
        extraData: [String: any Sendable] = [:]
    ) {
        self.request = request
        self.extraData = extraData
    }
}
