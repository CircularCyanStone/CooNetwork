import Foundation

/// payload parsing pipeline 中的可变换扩展点。
///
/// 设计定位：
/// - 该协议服务于 `NtkDataParsingInterceptor` 的主执行流，位于 `normalize -> transform -> decode` 中间阶段
/// - `transform(_:)` 可以改变 payload 的内容与形态，从而直接影响后续 decode / validation 行为
/// - 这里的职责是“改造输入”，典型场景包括解密、解包、结构重写、按协议收敛 payload
/// - 它不是只读事件，也不是观察者 hook；若只需要在解析生命周期节点做旁路处理，应使用 `iNtkParsingHooks`
///
/// 边界约束：
/// - `normalize` 只负责把原始响应收敛为可进入 pipeline 的 payload root
/// - 更深层的结构解释、协议适配与必要的严格化，应按需在 transformer 或 decoder 中完成
/// - transformer 的设计目标是扩展 parser 的执行能力，而不是被动读取状态
public protocol iNtkResponsePayloadTransforming: Sendable {
    func transform(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkPayload
}
