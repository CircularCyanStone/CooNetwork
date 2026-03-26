import Foundation

/// Interpret 阶段的封闭中间结果。
///
/// 它只描述 decoder 从 payload 中解释出了什么，
/// 不描述最终应该返回 response 还是抛出 error。
enum NtkInterpretation<ResponseData: Sendable>: Sendable {
    /// payload 已成功解释出的中间上下文。
    struct Decoded: Sendable {
        let code: NtkReturnCode
        let msg: String?
        let data: ResponseData?
        let request: iNtkRequest
        let clientResponse: NtkClientResponse
        let isCache: Bool
    }

    /// decode 失败后的统一中间上下文。
    ///
    /// `header` 只是失败上下文完整度的一部分，
    /// 不是另一种独立的 interpret 状态。
    struct DecodeFailure: Sendable {
        let decodeError: DecodingError
        let rawPayload: NtkPayload
        let header: NtkExtractedHeader?
        let request: iNtkRequest
        let clientResponse: NtkClientResponse
        let isCache: Bool
    }

    case decoded(Decoded)
    case decodeFailed(DecodeFailure)
}
