//
//  iNtkDecoderBuilding.swift
//  CooNetwork
//

import Foundation

/// 将 `NtkClientResponse.data` 构建为 `NtkResponseDecoder` 的策略协议
///
/// 不同 `iNtkClient` 返回的原始数据类型不同（`Data`、`NSDictionary` 等），
/// 通过实现此协议将任意数据源适配为统一的 `NtkResponseDecoder`，
/// 避免不必要的序列化/反序列化开销。
///
/// ## 内置实现
/// - `NtkDataDecoderBuilder`：默认实现，适配 `Data` 数据源（如 Alamofire）
/// - `NtkJsonObjectDecoderBuilder`：适配 `[String: any Sendable]` / `NSDictionary` 数据源（如 mPaaS）
///
/// ## 自定义示例
/// ```swift
/// struct MPaaSDecoderBuilder<
///     ResponseData: Sendable & Decodable,
///     Keys: iNtkResponseMapKeys
/// >: iNtkDecoderBuilding {
///     func build(_ sourceData: any Sendable, context: NtkInterceptorContext) async throws
///         -> NtkResponseDecoder<ResponseData, Keys>
///     {
///         guard let dict = sourceData as? NSDictionary else { throw NtkError.typeMismatch }
///         return NtkResponseDecoder(
///             code: NtkReturnCode(dict[Keys.code] as! Int),
///             data: dict[Keys.data] as? ResponseData,
///             msg: dict[Keys.msg] as? String
///         )
///     }
/// }
/// ```
public protocol iNtkDecoderBuilding<ResponseData, Keys>: Sendable {
    associatedtype ResponseData: Sendable & Decodable
    associatedtype Keys: iNtkResponseMapKeys

    func build(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys>
}

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

    public func build(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkResponseDecoder<ResponseData, Keys> {
        let dict: [AnyHashable: any Sendable]
        if let d = sourceData as? [AnyHashable: any Sendable] {
            dict = d
        } else if let d = sourceData as? NSDictionary, let cast = d as? [String: any Sendable] {
            dict = cast
        } else {
            throw NtkError.typeMismatch
        }

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
}
