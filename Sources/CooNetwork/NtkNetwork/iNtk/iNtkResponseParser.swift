//
//  iNtkResponseParser.swift
//  CooNetwork
//

import Foundation

/// 响应解析器协议
///
/// 将网络响应解析为强类型模型的组件协议。
/// 实现此协议以自定义响应解析逻辑。
///
/// ## 优先级保证
/// 框架内部通过 `NtkResponseParserBox` 将解析器包装为拦截器，
/// 优先级固定为 `inner` tier，运行在所有业务拦截器之后（请求流），
/// 之前返回（响应流）。实现者无需也无法干预优先级。
///
/// ## 使用方式
/// ```swift
/// struct MyResponseParser: iNtkResponseParser {
///     func intercept(context: NtkInterceptorContext,
///                    next: iNtkRequestHandler) async throws -> any iNtkResponse {
///         let response = try await next.handle(context: context)
///         // 解析逻辑...
///         return parsedResponse
///     }
/// }
/// ```
public protocol iNtkResponseParser: Sendable {
    /// 响应验证器
    /// parser 持有自己的 validation，无需通过 context 传递
    var validation: iNtkResponseValidation { get }

    @NtkActor
    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse
}

/// 响应解析器包装器（框架内部使用）
/// 将 iNtkResponseParser 包装为 iNtkInterceptor，优先级通过存储常量锁死，不存在覆写路径
struct NtkResponseParserBox: iNtkInterceptor, Sendable {
    let priority: NtkInterceptorPriority = .innerHigh
    private let wrapped: iNtkResponseParser

    init(_ parser: any iNtkResponseParser) {
        self.wrapped = parser
    }

    @NtkActor
    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        try await wrapped.intercept(context: context, next: next)
    }
}
