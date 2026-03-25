import Foundation

/// `decode()` 失败时用于错误路径的 header 信息
///
/// 包含 `code`、`msg` 以及反序列化后的原始 `data`（以 `NtkDynamicData` 承载），
/// 供后续策略层在错误路径继续做业务判定或构造错误上下文。
/// `extractHeader` 只负责补充可解释的协议信息，本身不表示解析成功。
public struct NtkExtractedHeader: Sendable {
    public let code: NtkReturnCode
    public let msg: String?
    public let data: NtkDynamicData?

    public init(code: NtkReturnCode, msg: String?, data: NtkDynamicData?) {
        self.code = code
        self.msg = msg
        self.data = data
    }
}

public protocol iNtkResponsePayloadDecoding<ResponseData, Keys>: Sendable {
    associatedtype ResponseData: Sendable & Decodable
    associatedtype Keys: iNtkResponseMapKeys

    func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys>

    func extractHeader(
        _ payload: NtkPayload,
        request: iNtkRequest
    ) throws -> NtkExtractedHeader?
}

public extension iNtkResponsePayloadDecoding {
    func extractHeader(
        _ payload: NtkPayload,
        request: iNtkRequest
    ) throws -> NtkExtractedHeader? {
        nil
    }
}
