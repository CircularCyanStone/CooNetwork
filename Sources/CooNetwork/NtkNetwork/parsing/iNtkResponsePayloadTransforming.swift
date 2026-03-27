import Foundation

/// payload parsing pipeline 中负责“输入改造”的扩展协议。
///
/// 该协议位于 `NtkDataParsingInterceptor` 的 `normalize -> transform -> decode` 主链中，
/// 用于在 payload 进入 decoder 之前，对内容或结构做前置收敛。
///
/// 设计定位：
/// - `normalize` 只负责决定哪些原始响应可以进入 pipeline，不负责协议语义解释
/// - `transformer` 负责把“可进入 pipeline 的 payload”改造成“更适合后续解释的 payload”
/// - `decoder` 负责解释 payload 的协议含义，而不是回头补做输入改造
///
/// 典型使用场景包括：
/// - 解密或解压响应体
/// - 解包外层协议壳
/// - 将多种历史协议收敛为统一结构
/// - 在 decode 前完成必要的结构重写
///
/// 边界约束：
/// - transformer 可以改变输入，但不负责最终成功/失败裁决
/// - transformer 不是只读观察者；若只需要在生命周期节点做旁路处理，应使用 `iNtkParsingHooks`
/// - transformer 的输出仍必须是可被后续阶段消费的 `NtkPayload`
public protocol iNtkResponsePayloadTransforming: Sendable {
    /// 对已经通过顶层结构 gate 的 payload 做前置改造。
    ///
    /// - Parameters:
    ///   - payload: 当前阶段接收到的统一 payload。它已经完成 `normalize`，但未必已经是 decoder 最适合消费的形态。
    ///   - context: 当前请求在拦截器链中的上下文，可用于读取请求相关配置或辅助信息，但不应借此承担结果裁决职责。
    /// - Returns: 供下一个 transformer 或 decoder 继续消费的新 payload。
    /// - Throws: 当输入无法被当前 transformer 处理，或改造过程依赖的外部条件失败时抛错；错误会终止主解析流程。
    func transform(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkPayload
}
