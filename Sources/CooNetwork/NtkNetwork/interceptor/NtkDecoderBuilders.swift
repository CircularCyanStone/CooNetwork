//
//  NtkDecoderBuilders.swift
//  CooNetwork
//

import Foundation

// NtkDataDecoderBuilder 和 NtkJsonObjectDecoderBuilder
// iNtkDecoderBuilding 协议的内置实现，与 NtkDataParsingInterceptor 配套

/// `[String: any Sendable]` / `NSDictionary` 数据源适配
///
/// 适用于内部已完成 JSON 反序列化、直接返回字典的客户端（如 mPaaS）。
/// `code` / `msg` 直接从字典提取，零额外开销；
/// `data` 字段需经过一次 `JSONSerialization` + `JSONDecoder` 以支持 `Codable` 解码。
public struct NtkJsonObjectDecoderBuilder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkDecoderBuilding {

    public init() {}

    private func extractDict(_ sourceData: any Sendable) -> [AnyHashable: any Sendable]? {
        if let d = sourceData as? [AnyHashable: any Sendable] { return d }
        if let d = sourceData as? NSDictionary, let cast = d as? [String: any Sendable] { return cast }
        return nil
    }

    public func build(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkResponseDecoder<ResponseData, Keys> {
        guard let dict = extractDict(sourceData) else { throw NtkError.typeMismatch }

        let code = NtkReturnCode(dict[Keys.code])
        let msg = dict[Keys.msg] as? String

        guard let dataRaw = dict[Keys.data] else {
            return NtkResponseDecoder(code: code, data: nil, msg: msg)
        }

        // data 字段需走 Codable 路径，一次序列化不可避免
        let dataBytes = try JSONSerialization.data(withJSONObject: dataRaw)
        let decodedData = try JSONDecoder().decode(ResponseData.self, from: dataBytes)
        return NtkResponseDecoder(code: code, data: decodedData, msg: msg)
    }

    public func extractHeader(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkExtractedHeader? {
        guard let dict = extractDict(sourceData) else { return nil }
        let rawData: NtkDynamicData? = (dict[Keys.data]).map { NtkDynamicData.from($0) }
        return NtkExtractedHeader(
            code: NtkReturnCode(dict[Keys.code]),
            msg: dict[Keys.msg] as? String,
            data: rawData
        )
    }
}

/// 默认 `Data` 数据源适配（适用于 Alamofire 等返回 `Data` 的客户端）
/// 空 Data 会触发 `DecodingError`，由上层包装为 `NtkError.decodeInvalid`
public struct NtkDataDecoderBuilder<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkDecoderBuilding {

    public init() {}

    public func build(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkResponseDecoder<ResponseData, Keys> {
        guard let data = sourceData as? Data else { throw NtkError.typeMismatch }
        return try JSONDecoder().decode(NtkResponseDecoder<ResponseData, Keys>.self, from: data)
    }

    public func extractHeader(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkExtractedHeader? {
        guard let data = sourceData as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: any Sendable]
        else { return nil }
        return NtkExtractedHeader(
            code: NtkReturnCode(json[Keys.code]),
            msg: json[Keys.msg] as? String,
            data: (json[Keys.data]).map { NtkDynamicData.from($0) }
        )
    }
}
