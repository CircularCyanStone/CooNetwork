import Foundation

// NtkDataPayloadDecoder 和 NtkJSONObjectPayloadDecoder
// iNtkResponsePayloadDecoding 协议的内置实现，与新的 payload pipeline 配套
//
// 注意：`NtkPayload` 接受顶层 object / array 作为结构化 payload，
// 但默认 header extraction / 业务 validation 更偏向 object / envelope 风格响应。
// 顶层 array 虽然是合法 payload，通常仍需要自定义 decoder（必要时自定义 validation）
// 才能被正确消费。
//
// `NtkJSONObjectPayloadDecoder` 只要求 envelope 是 object；其中 `data` 字段支持
// object / array / 字符串 / 数值 / 布尔值 / null 等任意 JSON 值。

public struct NtkJSONObjectPayloadDecoder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkResponsePayloadDecoding {

    public init() {}

    private func extractDict(_ payload: NtkPayload) -> [String: any Sendable]? {
        guard case .dynamic(let dynamic) = payload else { return nil }
        return dynamic.getDictionary()
    }

    /// 判断值是否可以作为 JSON 顶层标量交给 `JSONSerialization` 序列化。
    ///
    /// `JSONSerialization.isValidJSONObject` 对顶层标量始终返回 `false`，因此这里单独识别
    /// 字符串、布尔值、数值和 `null`，再配合 `.fragmentsAllowed` 使用。NaN / Infinity
    /// 无法写成 JSON 数字，交由后续 `NtkDynamicData` 路径抛出可捕获的编码错误。
    private func isJSONScalar(_ value: any Sendable) -> Bool {
        if value is String || value is NSString || value is NSNull {
            return true
        }
        guard let number = value as? NSNumber else { return false }
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return true
        }
        return number.doubleValue.isFinite
    }

    /// 将 `data` 字段值编码为 JSON 字节。
    ///
    /// 优先使用 `JSONSerialization`：客户端传入的通常就是 Foundation JSON 树，直接序列化
    /// 比 `JSONEncoder` + `NtkDynamicData` 少一层包装和临时对象，性能更好。只有值本身是
    /// `NtkDynamicData`（或容器中嵌入了它）这类 `JSONSerialization` 无法表示的混合树时，
    /// 才回退到 `NtkDynamicData` 的 Codable 编码。
    private func makeDataBytes(from value: any Sendable) throws -> Data {
        if isJSONScalar(value) || JSONSerialization.isValidJSONObject(value) {
            return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
        }
        return try JSONEncoder().encode(NtkDynamicData.from(value))
    }

    public func decode(
        _ payload: NtkPayload,
        context: NtkParsingContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys> {
        guard let dict = extractDict(payload) else {
            throw NtkError.Serialization.invalidEnvelope
        }

        let code = NtkReturnCode(dict[Keys.code])
        let msg = dict[Keys.msg] as? String

        // `data` 字段在协议上不限定为 JSON object：字符串、数值、布尔值等基础类型同样合法，
        // 字段值为 `null` 时按“无数据”处理。
        guard let dataRaw = dict[Keys.data], !(dataRaw is NSNull) else {
            return NtkResponseDecoder(code: code, data: nil, msg: msg)
        }

        // `JSONSerialization.data(withJSONObject:)` 默认只接受顶层 object / array，遇到基础类型
        // 会抛出不可捕获的 Objective-C 异常；`makeDataBytes` 内部通过 `.fragmentsAllowed` 和
        // `NtkDynamicData` 回退统一处理 object、array 以及全部 JSON 标量。
        let dataBytes = try makeDataBytes(from: dataRaw)
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
        context: NtkParsingContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys> {
        guard case .data(let data) = payload else {
            throw NtkError.Serialization.invalidDataPayload(recoveredResponse: nil)
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
