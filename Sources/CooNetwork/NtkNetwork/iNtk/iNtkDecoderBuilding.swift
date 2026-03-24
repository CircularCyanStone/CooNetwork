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
/// ## 内置实现（位于 `interceptor/NtkDecoderBuilders.swift`）
/// - `NtkDataDecoderBuilder`：默认实现，适配 `Data` 数据源（如 Alamofire）
/// - `NtkJsonObjectDecoderBuilder`：适配顶层可按字符串键读取的字典对象，以及可安全桥接为字符串键字典的 `NSDictionary`（如 mPaaS）
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

/// `build()` 抛出时用于错误路径的 header 信息
///
/// 包含 `code`、`msg` 以及反序列化后的原始 `data`（以 `NtkDynamicData` 承载），
/// 供业务端在 `NtkError.validation` 时直接访问，无需二次序列化。
public struct NtkExtractedHeader: Sendable {
    public let code: NtkReturnCode
    public let msg: String?
    /// 反序列化后的原始数据
    public let data: NtkDynamicData?
    
    public init(code: NtkReturnCode, msg: String?, data: NtkDynamicData?) {
        self.code = code
        self.msg = msg
        self.data = data
    }
}

public protocol iNtkDecoderBuilding<ResponseData, Keys>: Sendable {
    associatedtype ResponseData: Sendable & Decodable
    associatedtype Keys: iNtkResponseMapKeys

    func build(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<ResponseData, Keys>

    /// `build()` 抛出时调用，轻量提取 header（code / msg / 原始 data），
    /// 用于在 error path 优先判断 validation 失败，并将原始数据透传给业务端。
    ///
    /// - 默认实现返回 `nil`，降级为 `NtkError.decodeInvalid`，不影响现有自定义实现
    /// - 仅在 error path 调用，不影响正常请求性能
    func extractHeader(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkExtractedHeader?
}

extension iNtkDecoderBuilding {
    public func extractHeader(
        _ sourceData: any Sendable,
        context: NtkInterceptorContext
    ) throws -> NtkExtractedHeader? {
        return nil
    }
}

