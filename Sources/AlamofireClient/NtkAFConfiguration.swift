//
//  NtkAFConfiguration.swift
//  CooNetwork
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif

/// Alamofire 请求使用的响应解析策略。
///
/// 使用 ``standard(validation:hooks:transformers:)`` 组合框架内置解析流水线；只有需要完整接管
/// 响应解析时才使用 ``custom(_:)``。两种模式互斥，避免自定义 parser 与单项解析参数同时出现时
/// 产生参数被静默忽略的歧义。
public struct NtkAFParsingStrategy<ResponseData: Sendable>: Sendable {

    let responseParser: any iNtkResponseParser

    private init(responseParser: any iNtkResponseParser) {
        self.responseParser = responseParser
    }

    /// 使用默认 `AFResponseMapKeys` 和 Data decoder 创建标准解析流水线。
    public static func standard(
        validation: any iNtkResponseValidation = AFDefaultResponseValidation(),
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = []
    ) -> Self where ResponseData: Decodable {
        standard(
            keys: AFResponseMapKeys.self,
            validation: validation,
            hooks: hooks,
            transformers: transformers
        )
    }

    /// 使用自定义响应字段映射和默认 Data decoder 创建标准解析流水线。
    public static func standard<Keys: iNtkResponseMapKeys>(
        keys: Keys.Type,
        validation: any iNtkResponseValidation = AFDefaultResponseValidation(),
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = []
    ) -> Self where ResponseData: Decodable {
        Self(
            responseParser: NtkDataParsingInterceptor<ResponseData, Keys>(
                validation: validation,
                hooks: hooks,
                transformers: transformers
            )
        )
    }

    /// 使用自定义响应字段映射和 payload decoder 创建标准解析流水线。
    public static func standard<
        Keys: iNtkResponseMapKeys,
        Decoder: iNtkResponsePayloadDecoding<ResponseData, Keys>
    >(
        keys: Keys.Type,
        validation: any iNtkResponseValidation = AFDefaultResponseValidation(),
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = [],
        decoder: Decoder
    ) -> Self where ResponseData: Decodable {
        Self(
            responseParser: NtkDataParsingInterceptor<ResponseData, Keys>(
                validation: validation,
                hooks: hooks,
                transformers: transformers,
                decoder: decoder
            )
        )
    }

    /// 完整替换响应解析流程。
    ///
    /// 自定义 parser 自行负责其所需的 validation、转换、解码和观察行为。
    public static func custom(_ responseParser: any iNtkResponseParser) -> Self {
        Self(responseParser: responseParser)
    }
}

/// 单次 Alamofire 网络请求的组装配置。
///
/// 应用可通过配置工厂复用该值，并在少数特殊请求中传入不同的 client、解析策略或缓存存储。
public struct NtkAFConfiguration<ResponseData: Sendable & Decodable>: Sendable {

    /// 执行底层请求的 Alamofire client。
    public let client: AFClient

    /// 响应解析策略。
    public let parsing: NtkAFParsingStrategy<ResponseData>

    /// 可选缓存存储；请求自身还需启用 `cacheConfiguration` 才会实际读写缓存。
    public let cacheStorage: (any iNtkCacheStorage)?

    public init(
        client: AFClient = AFClient(),
        parsing: NtkAFParsingStrategy<ResponseData> = .standard(),
        cacheStorage: (any iNtkCacheStorage)? = nil
    ) {
        self.client = client
        self.parsing = parsing
        self.cacheStorage = cacheStorage
    }

    /// 默认 Alamofire 请求配置。
    public static var `default`: Self {
        Self()
    }
}
