import Foundation

/// `decode()` 失败后用于补充错误路径上下文的协议头信息。
///
/// 当 decoder 无法把 payload 强解码为目标 `ResponseData` 时，
/// 仍可能从响应中恢复出最小的 envelope 信息，例如 `code` / `msg` / 原始 `data` 字段。
/// 这些信息可供 policy 在错误路径继续做业务判定或构造更可解释的错误上下文。
///
/// 设计定位：
/// - 它表示“还能解释出哪些协议信息”，不是“解析已经成功”
/// - 它属于 decoder 的错误侧解释结果，不是最终 response
/// - 它为 policy 提供 fallback 所需的最小 header 视图
public struct NtkExtractedHeader: Sendable {
    /// 从 payload 中恢复出的业务返回码。
    public let code: NtkReturnCode

    /// 从 payload 中恢复出的业务消息文本。
    public let msg: String?

    /// 从 payload 中恢复出的原始 `data` 字段。
    ///
    /// 这里使用 `NtkDynamicData` 承载，是为了在错误路径保留结构化可读性，
    /// 而不要求调用方重新对整个原始响应做一次序列化/反序列化。
    public let data: NtkDynamicData?

    /// 创建一个错误路径使用的 header 恢复结果。
    ///
    /// - Parameters:
    ///   - code: 已恢复出的业务返回码。
    ///   - msg: 已恢复出的业务消息文本。
    ///   - data: 已恢复出的原始 `data` 字段内容；若协议缺失该字段则为 `nil`。
    public init(code: NtkReturnCode, msg: String?, data: NtkDynamicData?) {
        self.code = code
        self.msg = msg
        self.data = data
    }
}

/// payload 协议解释器。
///
/// 该协议位于 parsing pipeline 的 interpret 阶段，负责把 `NtkPayload` 解释为协议层结果。
/// 它既承担成功路径的强解码，也承担失败路径下尽量恢复 header 信息的职责。
///
/// 设计定位：
/// - transformer 负责改输入，decoder 负责读懂输入
/// - decoder 只解释 payload 能表达什么，不负责最终 success / failure 裁决
/// - 只要逻辑仍在回答“还能从 payload 里解释出什么协议信息”，它就属于 decoder 边界
public protocol iNtkResponsePayloadDecoding<ResponseData, Keys>: Sendable {
    associatedtype ResponseData: Sendable & Decodable
    associatedtype Keys: iNtkResponseMapKeys

    /// 将统一 payload 强解释为目标响应模型与协议头信息。
    ///
    /// - Parameters:
    ///   - payload: 已完成 normalize 和 transformer 收敛的统一 payload。
    ///   - context: 当前请求上下文，可用于读取与解码相关的环境信息。
    /// - Returns: 包含协议层 `code` / `msg` / `data` 的解码结果，供后续 policy 决定最终 outcome。
    /// - Throws: 当 payload 形态与 decoder 预期不符，或目标模型 `ResponseData` 解码失败时抛错。
    func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys>

    /// 在强解码失败后，尽量从 payload 中恢复最小可用的协议头信息。
    ///
    /// - Parameters:
    ///   - payload: 与 `decode` 相同的统一 payload。此时调用方通常已知道完整解码失败，希望恢复错误路径的最小业务上下文。
    ///   - request: 当前请求对象，用于需要按请求协议解释 header 的场景。
    /// - Returns: 若能够恢复出 header 信息，则返回 `NtkExtractedHeader`；若当前 decoder 无法提供该能力，则返回 `nil`。
    /// - Throws: 当恢复过程中出现不可忽略的解释错误时抛错。
    /// - Note: `extractHeader` 只表示“能恢复出什么”，不表示“最终应该返回什么”。最终落地仍由 policy 决定。
    func extractHeader(
        _ payload: NtkPayload,
        request: iNtkRequest
    ) throws -> NtkExtractedHeader?
}

public extension iNtkResponsePayloadDecoding {
    /// 默认不提供 header 恢复能力。
    ///
    /// - Parameters:
    ///   - payload: 当前统一 payload。
    ///   - request: 当前请求对象。
    /// - Returns: 始终返回 `nil`，表示该 decoder 仅负责成功路径 decode，不提供错误路径 header 恢复。
    func extractHeader(
        _ payload: NtkPayload,
        request: iNtkRequest
    ) throws -> NtkExtractedHeader? {
        nil
    }
}
