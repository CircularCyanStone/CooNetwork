//
//  NtkDataParsingInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

// 通用响应解析拦截器，通过 iNtkResponsePayloadBuilding 支持多种数据源（Data、NSDictionary 等）。

import Foundation

/// 通用响应解析拦截器
///
/// 将 `NtkClientResponse.data`（`any Sendable`）解析为强类型 `NtkResponse<ResponseData>`。
///
/// ## 多数据源支持
///
/// 通过 `iNtkResponsePayloadBuilding` 协议适配不同 `iNtkClient` 的数据格式：
/// - 默认使用 `NtkDataPayloadBuilder`：`data as? Data` → `JSONDecoder`
/// - 自定义：实现 `iNtkResponsePayloadBuilding` 直接从 `NSDictionary` 等构建，零转换开销
///
/// ## 生命周期扩展
///
/// 通过 `hooks` 注入自定义逻辑（token 校验、埋点等），详见 `iNtkParsingHooks`。
public struct NtkDataParsingInterceptor<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkResponseParser {

    public let validation: iNtkResponseValidation
    private let hooks: [any iNtkParsingHooks]
    private let builder: any iNtkResponsePayloadBuilding<ResponseData, Keys>

    /// 初始化解析拦截器（使用默认 Data 数据源）
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = []
    ) {
        self.validation = validation
        self.hooks = hooks
        self.builder = NtkDataPayloadBuilder<ResponseData, Keys>()
    }

    /// 初始化解析拦截器（自定义数据源）
    /// - Parameters:
    ///   - validation: 业务校验器
    ///   - hooks: 生命周期钩子，按顺序依次执行
    ///   - builder: 自定义数据源适配器，实现 `iNtkResponsePayloadBuilding`
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        builder: any iNtkResponsePayloadBuilding<ResponseData, Keys>
    ) {
        self.validation = validation
        self.hooks = hooks
        self.builder = builder
    }

    /// 拦截响应并解析为目标类型
    public func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)

        // 如果已经是目标类型，直接返回
        if let ntkResponse = response as? NtkResponse<ResponseData> {
            return ntkResponse
        }

        // 期待拿到客户端原始响应
        guard let clientResponse = response as? NtkClientResponse else {
            throw NtkError.typeMismatch
        }
        let request = context.mutableRequest.originalRequest

        do {
            // 通过 builderClosure 将任意数据源转为 NtkResponseDecoder
            let decoderResponse = try await builder.build(clientResponse.data, context: context)

            logger.debug(
                """
                ---------------------Data response start-------------------------
                \(request)
                参数：\(request.parameters as [String: any Sendable]? ?? [:])
                code: \(decoderResponse.code)  msg: \(decoderResponse.msg ?? "")
                ---------------------Data response end-------------------------
                """,
                category: .network
            )

            // [H2] retCode / msg hook
            for hook in hooks {
                try await hook.didDecodeHeader(
                    retCode: decoderResponse.code.intValue,
                    msg: decoderResponse.msg,
                    context: context
                )
            }

            // 1. NtkNever：不需要数据内容
            if ResponseData.self is NtkNever.Type {
                let fixResponse = NtkResponse(
                    code: decoderResponse.code,
                    data: NtkNever() as! ResponseData,
                    msg: decoderResponse.msg,
                    response: clientResponse,
                    request: request,
                    isCache: clientResponse.isCache
                )
                try await runValidation(fixResponse, request: request, context: context)
                for hook in hooks { try await hook.didComplete(fixResponse, context: context) }
                return fixResponse
            }

            guard let retData = decoderResponse.data else {
                // 2. 常规数据：data 为 nil，先以 Optional 形态做业务校验
                let optionalResponse = NtkResponse<ResponseData?>(
                    code: decoderResponse.code,
                    data: nil,
                    msg: decoderResponse.msg,
                    response: clientResponse,
                    request: request,
                    isCache: clientResponse.isCache
                )
                try await runValidation(optionalResponse, request: request, context: context)
                throw NtkError.serviceDataEmpty
            }

            // 3. 常规数据：data 不为空
            let fixResponse = NtkResponse(
                code: decoderResponse.code,
                data: retData,
                msg: decoderResponse.msg,
                response: clientResponse,
                request: request,
                isCache: clientResponse.isCache
            )
            try await runValidation(fixResponse, request: request, context: context)
            for hook in hooks { try await hook.didComplete(fixResponse, context: context) }
            return fixResponse

        } catch let error as DecodingError {
            // 尝试轻量提取 header，优先判断是否为业务 validation 失败
            // 避免将 retcode 失败时 data 结构不匹配误报为 decodeInvalid
            // 同时将反序列化后的原始 data 透传，业务端无需二次序列化
            if let header = try? builder.extractHeader(clientResponse.data, request: request) {
                let errResponse = NtkResponse<NtkDynamicData?>(
                    code: header.code,
                    data: header.data,
                    msg: header.msg,
                    response: clientResponse,
                    request: request,
                    isCache: clientResponse.isCache
                )
                try await runValidation(errResponse, request: request, context: context)
            }
            throw NtkError.decodeInvalid(error, clientResponse.data, request)
        }
    }

    // MARK: - Private Helpers

    private func runValidation(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkInterceptorContext
    ) async throws {
        for hook in hooks { try await hook.willValidate(response, context: context) }
        try await validate(response, request: request, context: context)
    }

    private func validate(
        _ response: any iNtkResponse,
        request: iNtkRequest,
        context: NtkInterceptorContext
    ) async throws {
        guard validation.isServiceSuccess(response) else {
            for hook in hooks {
                try await hook.didValidateFail(response, context: context)
            }
            throw NtkError.validation(request, response)
        }
    }
}
