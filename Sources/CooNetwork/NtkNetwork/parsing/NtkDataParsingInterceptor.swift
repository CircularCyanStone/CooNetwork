//
//  NtkDataParsingInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation

/// 将客户端原始响应收敛为业务侧强类型响应的通用解析拦截器。
///
/// 解析过程被拆成四个职责明确的阶段：
///
/// 1. `acquire`：执行下游处理器，并判断响应应直接透传还是进入原始响应解析链。
/// 2. `prepare`：建立稳定的 `NtkPayload` 边界，再按注册顺序执行前置转换。
/// 3. `interpret`：由 decoder 解释协议 envelope；强解码失败时尽量保留可用于诊断和业务判定的上下文。
/// 4. `NtkDefaultResponseParsingPolicy`：结合 validation 对解释结果作最终裁决，返回响应或抛出明确错误。
///
/// 这种分层有两个重要约束：
///
/// - transformer 只改变 decoder 的输入，不决定业务成功与否；业务裁决始终留在 policy。
/// - hooks 只观察已经发生的生命周期事件，其异常由 dispatcher 隔离，不会改写主流程结果。
///
/// `ResponseData` 决定最终业务数据类型，`Keys` 决定标准 envelope 中 `code`、`data`、`msg`
/// 的字段映射。若服务端载荷或协议不适合默认 JSON `Data` 解码，可组合 transformer 与
/// 自定义 decoder，而无需复制整条解析流程。
public struct NtkDataParsingInterceptor<
    ResponseData: Sendable & Decodable,
    Keys: iNtkResponseMapKeys
>: iNtkResponseParser {

    /// 统一分发生命周期通知，并把观察者异常隔离在解析主流程之外。
    private let dispatcher: NtkParsingHookDispatcher

    /// 按数组顺序组成输入转换链；后一个 transformer 接收前一个的输出。
    private let transformers: [any iNtkResponsePayloadTransforming]

    /// 负责理解转换完成后的 payload，不负责业务成功判定。
    private let decoder: any iNtkResponsePayloadDecoding<ResponseData, Keys>

    /// 集中处理空业务数据、业务码校验、解码失败恢复以及最终 hook 时机。
    private let policy: NtkDefaultResponseParsingPolicy<ResponseData>

    /// 创建使用默认 `Data` payload decoder 的解析器。
    ///
    /// 默认 decoder 预期 transformer 链的最终输出仍为 `.data`，并使用 `JSONDecoder`
    /// 按 `Keys` 指定的 envelope 字段解码。若 transformer 最终产出 `.dynamic`，应改用能够消费
    /// 动态结构的 decoder，例如 `NtkJSONObjectPayloadDecoder`，或提供自定义实现。
    ///
    /// - Parameters:
    ///   - validation: 最终业务成功判定规则。HTTP 请求成功不代表业务响应一定被放行。
    ///   - hooks: 解析里程碑的只读观察者；按传入顺序通知，单个 hook 失败不会中断后续通知。
    ///   - transformers: decoder 之前执行的转换链，适合解密、解压、拆 envelope 或兼容旧协议。
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = []
    ) {
        let dispatcher = NtkParsingHookDispatcher(hooks: hooks)
        self.dispatcher = dispatcher
        self.transformers = transformers
        self.decoder = NtkDataPayloadDecoder<ResponseData, Keys>()
        self.policy = NtkDefaultResponseParsingPolicy(
            validation: validation,
            dispatcher: dispatcher
        )
    }

    /// 创建使用自定义 payload decoder 的解析器。
    ///
    /// 自定义 decoder 只需要负责“如何解释 payload”；成功响应的构造、validation、hook 分发和
    /// `DecodingError` 包装仍由公共流程处理。decoder 若实现 `extractHeader`，强解码失败后 policy
    /// 还可利用恢复出的业务码优先识别服务端拒绝，避免把业务错误误报成纯序列化错误。
    ///
    /// - Parameters:
    ///   - validation: 最终业务成功判定规则。
    ///   - hooks: 解析里程碑的只读观察者。
    ///   - transformers: 按顺序运行的 payload 转换链。
    ///   - decoder: 与转换链最终输出形态匹配的协议解释器。
    public init(
        validation: iNtkResponseValidation,
        hooks: [any iNtkParsingHooks] = [],
        transformers: [any iNtkResponsePayloadTransforming] = [],
        decoder: any iNtkResponsePayloadDecoding<ResponseData, Keys>
    ) {
        let dispatcher = NtkParsingHookDispatcher(hooks: hooks)
        self.dispatcher = dispatcher
        self.transformers = transformers
        self.decoder = decoder
        self.policy = NtkDefaultResponseParsingPolicy(
            validation: validation,
            dispatcher: dispatcher
        )
    }

    /// 响应方向上的解析入口。
    ///
    /// 该方法先让下游处理器完成请求与客户端响应生产，再决定是否启动解析。若下游已经返回
    /// `NtkResponse<ResponseData>`，说明同类型响应已由缓存、重试或其他组件构造完成，此处直接
    /// 透传，避免重复转换、重复 validation 和重复触发 hooks。
    ///
    /// 只有原始 `NtkClientResponse` 会进入完整解析链；其他响应类型表示拦截器组合与本解析器的
    /// 契约不匹配，会被明确拒绝，而不是尝试猜测其数据布局。
    ///
    /// - Parameters:
    ///   - context: 当前拦截器链共享上下文。仅在 actor 隔离阶段读取其可变状态。
    ///   - next: 负责继续执行请求链并产出待解析响应的下游处理器。
    /// - Returns: 已透传或完成业务裁决的响应。
    /// - Throws: 下游错误、载荷准备错误、解码错误或业务 validation 错误。
    @NtkActor
    public func intercept(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        switch try await acquire(context: context, next: next) {
        case .typedPassthrough(let passthrough):
            return passthrough
        case .raw(let acquired):
            return try await process(acquired)
        }
    }

    /// 在只读、可发送的解析快照上串联后三个阶段。
    ///
    /// `acquire` 已经把可变拦截器上下文收敛为 `NtkParsingContext`，因此 transformer、decoder
    /// 与 policy 无需继续持有网络 client 或修改共享请求状态。这也是后续阶段不需要依赖
    /// `NtkActor` 隔离的关键边界。
    private func process(_ acquired: AcquiredResponse) async throws -> any iNtkResponse {
        let prepared = try await prepare(acquired)
        let interpreted = try await interpret(prepared, context: acquired.parsingContext)
        return try await policy.decide(from: interpreted, context: acquired.parsingContext)
    }

    /// 从下游取得响应，并建立解析阶段所需的稳定现场。
    ///
    /// 快照在 `next.handle` 返回之后创建，因此会包含下游拦截器在请求阶段完成的配置结果。
    /// 此后即使原始 `NtkInterceptorContext` 的结构值再发生变化，解析扩展点看到的请求与
    /// `extraData` 仍保持一致，避免一次解析中的多个阶段观察到不同状态。该保证不等同于递归
    /// 深拷贝：容器内部若保存引用类型，其对象自身仍遵循原有的共享与并发约束。
    ///
    /// 返回 `Acquisition` 而不是一组可选值，是为了让“已经是目标类型”和“需要解析的客户端响应”
    /// 成为互斥状态，后续代码不必处理无意义的字段组合。
    @NtkActor
    private func acquire(
        context: NtkInterceptorContext,
        next: iNtkRequestHandler
    ) async throws -> Acquisition {
        let response = try await next.handle(context: context)

        if let typedPassthrough = response as? NtkResponse<ResponseData> {
            return .typedPassthrough(typedPassthrough)
        }

        guard let clientResponse = response as? NtkClientResponse else {
            throw NtkError.invalidResponseType(response: response)
        }

        let mutableRequest = context.request
        return .raw(
            AcquiredResponse(
                request: mutableRequest.originalRequest,
                clientResponse: clientResponse,
                parsingContext: NtkParsingContext(
                    request: mutableRequest,
                    extraData: context.extraData
                )
            )
        )
    }

    /// 把客户端数据收敛成 decoder 可以稳定消费的最终 payload。
    ///
    /// 空 `Data` 在这里单独报告为“响应体为空”，使其与“有内容但协议无法解析”区分开；结构化
    /// object/array 是否可进入流水线则由 `NtkPayload.normalize` 统一判断。完成归一化后，所有
    /// transformer 按注册顺序执行，任一转换失败都会立即终止，decoder 与 hooks 均不会运行。
    ///
    /// `PreparedPayload.payload` 保存的是转换链的最终结果。若后续强解码失败，这份结果也会作为
    /// 错误上下文保留，因为它比转换前的字节更能反映 decoder 实际收到的内容。
    private func prepare(_ acquired: AcquiredResponse) async throws -> PreparedPayload {
        if let body = acquired.clientResponse.data as? Data, body.isEmpty {
            throw NtkError.responseBodyEmpty(clientResponse: acquired.clientResponse)
        }

        let normalizedPayload = try NtkPayload.normalize(from: acquired.clientResponse.data)
        let finalPayload = try await transform(
            normalizedPayload,
            context: acquired.parsingContext
        )
        return PreparedPayload(
            request: acquired.request,
            clientResponse: acquired.clientResponse,
            payload: finalPayload
        )
    }

    /// 将准备完成的 payload 解释为 policy 可裁决的封闭中间结果。
    ///
    /// 完整 decode 成功后才发送 `didDecodeHeader`：该事件表示整个 envelope 已按目标模型成功解释，
    /// 不只是错误路径上勉强恢复出了 `code` / `msg`。此时仍未执行业务 validation，因此收到该
    /// 通知不等于响应最终会成功返回。
    ///
    /// 这里只把标准 `DecodingError` 收敛为 `.decodeFailed`，让 policy 有机会结合恢复出的 header
    /// 区分业务拒绝和模型不匹配。decoder 主动抛出的领域错误或输入形态错误会保持原样向上传递，
    /// 避免丢失比通用序列化错误更准确的语义。
    private func interpret(
        _ prepared: PreparedPayload,
        context: NtkParsingContext
    ) async throws -> NtkInterpretation<ResponseData> {
        do {
            let decoderResponse = try await decoder.decode(prepared.payload, context: context)
            logDecodedHeader(decoderResponse, request: prepared.request)

            await dispatcher.didDecodeHeader(
                retCode: decoderResponse.code.intValue,
                msg: decoderResponse.msg,
                context: context
            )

            let decoded = NtkInterpretation<ResponseData>.Decoded(
                code: decoderResponse.code,
                msg: decoderResponse.msg,
                data: decoderResponse.data,
                request: prepared.request,
                clientResponse: prepared.clientResponse,
                isCache: prepared.clientResponse.isCache
            )
            return .decoded(decoded)
        } catch let error as DecodingError {
            return makeInterpretFailureResult(from: error, prepared: prepared)
        }
    }

    /// 记录已经可靠解出的协议头与请求参数。
    ///
    /// 日志位于完整 decode 成功分支，避免将错误恢复阶段得到的不完整 header 误标记为正常响应。
    private func logDecodedHeader(
        _ decoderResponse: NtkResponseDecoder<ResponseData, Keys>,
        request: iNtkRequest
    ) {
        logger.debug(
            "[Response] \(request) params=\(request.parameters as [String: any Sendable]? ?? [:]) code=\(decoderResponse.code) msg=\(decoderResponse.msg ?? "")",
            category: .network
        )
    }

    /// 构建可供 policy 继续判定的解码失败现场。
    ///
    /// header 恢复属于尽力而为：它能提升最终错误的可解释性，但不应覆盖最初的 `DecodingError`。
    /// 因此 `extractHeader` 自身失败会被降级为“无可恢复 header”，原始解码错误、最终 payload、
    /// 请求和客户端响应仍会完整进入 policy。恢复出 header 也不代表解码成功，policy 最多用它先
    /// 执行业务 validation；若业务码被放行，最终仍会抛出数据解码失败。
    private func makeInterpretFailureResult(
        from error: DecodingError,
        prepared: PreparedPayload
    ) -> NtkInterpretation<ResponseData> {
        let failure = NtkInterpretation<ResponseData>.DecodeFailure(
            decodeError: error,
            rawPayload: prepared.payload,
            header: try? decoder.extractHeader(prepared.payload, request: prepared.request),
            request: prepared.request,
            clientResponse: prepared.clientResponse,
            isCache: prepared.clientResponse.isCache
        )
        return .decodeFailed(failure)
    }

    /// 以确定顺序执行 payload 转换链。
    ///
    /// 转换采用串行组合而非并行执行，因为每一步都允许改变 payload 的内容与表示形式，后一步
    /// 必须基于前一步的输出工作。空数组表示保持 normalize 后的 payload 原样交给 decoder。
    private func transform(
        _ payload: NtkPayload,
        context: NtkParsingContext
    ) async throws -> NtkPayload {
        var current = payload
        for transformer in transformers {
            current = try await transformer.transform(current, context: context)
        }
        return current
    }

    /// 描述 acquire 阶段仅有的两种合法结果，防止透传响应意外进入重复解析链。
    private enum Acquisition: Sendable {
        /// 下游已产生与当前 `ResponseData` 完全匹配的强类型响应。
        case typedPassthrough(NtkResponse<ResponseData>)

        /// 下游产出客户端原始响应，需要继续 normalize、transform、decode 和 policy 裁决。
        case raw(AcquiredResponse)
    }

    /// 原始响应及其解析现场快照。
    ///
    /// 三个值在 acquire 阶段一次性绑定，保证后续日志、错误和最终响应引用同一次请求现场。
    private struct AcquiredResponse: Sendable {
        let request: iNtkRequest
        let clientResponse: NtkClientResponse
        let parsingContext: NtkParsingContext

        init(
            request: iNtkRequest,
            clientResponse: NtkClientResponse,
            parsingContext: NtkParsingContext
        ) {
            self.request = request
            self.clientResponse = clientResponse
            self.parsingContext = parsingContext
        }
    }

    /// prepare 阶段的不可变输出。
    ///
    /// `payload` 已通过入口形态检查并完成全部 transformer；它既是 decoder 的唯一输入，也是解码
    /// 失败时保留的诊断载荷。请求和客户端响应继续随结果传递，以避免后续阶段重新访问共享上下文。
    private struct PreparedPayload: Sendable {
        let request: iNtkRequest
        let clientResponse: NtkClientResponse
        let payload: NtkPayload
    }

}
