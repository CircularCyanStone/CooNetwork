import Foundation

// NtkDataPayloadDecoder 和 NtkJSONObjectPayloadDecoder
// iNtkResponsePayloadDecoding 协议的内置实现，与新的 payload pipeline 配套
//
// 注意：`NtkPayload` 接受顶层 object / array 作为结构化 payload，
// 但默认 header extraction / 业务 validation 更偏向 object / envelope 风格响应。
// 顶层 array 虽然是合法 payload，通常仍需要自定义 decoder（必要时自定义 validation）
// 才能被正确消费。

public struct NtkJSONObjectPayloadDecoder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkResponsePayloadDecoding {

    public init() {}

    private func extractDict(_ payload: NtkPayload) -> [String: any Sendable]? {
        guard case .dynamic(let dynamic) = payload else { return nil }
        return dynamic.getDictionary()
    }

    public func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys> {
        guard let dict = extractDict(payload) else {
            throw NtkError.responseSerializationFailed(
                reason: .invalidEnvelope(
                    request: nil,
                    clientResponse: nil,
                    rawPayload: nil
                )
            )
        }

        let code = NtkReturnCode(dict[Keys.code])
        let msg = dict[Keys.msg] as? String

        guard let dataRaw = dict[Keys.data] else {
            return NtkResponseDecoder(code: code, data: nil, msg: msg)
        }

        let dataBytes = try JSONSerialization.data(withJSONObject: dataRaw)
        let decodedData = try JSONDecoder().decode(ResponseData.self, from: dataBytes)
        return NtkResponseDecoder(code: code, data: decodedData, msg: msg)
    }

    public func extractHeader(
        _ payload: NtkPayload,
        request: iNtkRequest
    ) throws -> NtkExtractedHeader? {
        guard let dict = extractDict(payload) else { return nil }
        let rawData = dict[Keys.data].map { NtkDynamicData.from($0) }
        return NtkExtractedHeader(
            code: NtkReturnCode(dict[Keys.code]),
            msg: dict[Keys.msg] as? String,
            data: rawData
        )
    }
}

public struct NtkDataPayloadDecoder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkResponsePayloadDecoding {

    public init() {}

    public func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys> {
        guard case .data(let data) = payload else {
            throw NtkError.responseSerializationFailed(
                reason: .invalidDataPayload(
                    request: nil,
                    clientResponse: nil,
                    recoveredResponse: nil
                )
            )
        }
        return try JSONDecoder().decode(NtkResponseDecoder<ResponseData, Keys>.self, from: data)
    }

    public func extractHeader(
        _ payload: NtkPayload,
        request: iNtkRequest
    ) throws -> NtkExtractedHeader? {
        guard case .data(let data) = payload,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: any Sendable]
        else { return nil }
        return NtkExtractedHeader(
            code: NtkReturnCode(json[Keys.code]),
            msg: json[Keys.msg] as? String,
            data: json[Keys.data].map { NtkDynamicData.from($0) }
        )
    }
}
