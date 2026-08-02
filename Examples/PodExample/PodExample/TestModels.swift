//
//  TestModels.swift
//  PodExample
//
//  Created by Claude Code on 2026/3/15.
//

import Foundation
import CooNetwork

// MARK: - JSONPlaceholder Models

struct Post: Decodable, Sendable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}

struct Comment: Decodable, Sendable {
    let postId: Int
    let id: Int
    let name: String
    let email: String
    let body: String
}

struct HttpBinResponse: Decodable, Sendable {
    let args: [String: String]
    let headers: [String: String]
    let origin: String
    let url: String
}

func headerValue(in headers: [String: String], named name: String) -> String? {
    headers.first { key, _ in
        key.caseInsensitiveCompare(name) == .orderedSame
    }?.value
}

// MARK: - Test Result Models

enum TestStatus {
    case passed
    case failed
    case skipped

    var emoji: String {
        switch self {
        case .passed: return "✅"
        case .failed: return "❌"
        case .skipped: return "⏭"
        }
    }

    var displayName: String {
        switch self {
        case .passed: return "PASSED"
        case .failed: return "FAILED"
        case .skipped: return "SKIPPED"
        }
    }
}

struct TestResult: Sendable {
    let name: String
    let status: TestStatus
    let duration: TimeInterval
    let details: String
    let evidence: String?

    var formattedOutput: String {
        var output = "\(status.emoji) \(name) (\(String(format: "%.2f", duration))s)\n"
        output += "   Status: \(status.displayName)\n"
        output += "   Details: \(details)"
        if let evidence = evidence {
            output += "\n   Evidence: \(evidence)"
        }
        return output
    }
}

struct TestSuite {
    let name: String
    let description: String
    let action: () async throws -> TestResult
}

// MARK: - Test Requests

struct JSONPlaceholderRequest: iAFRequest {
    let path: String
    let method: NtkHTTPMethod
    let parameters: [String: any Sendable]?

    var baseURL: URL? {
        URL(string: "https://jsonplaceholder.typicode.com")
    }

    var checkLogin: Bool {
        false
    }
}

struct HttpBinRequest: iAFRequest {
    let path: String
    let method: NtkHTTPMethod
    let parameters: [String: any Sendable]?

    var baseURL: URL? {
        URL(string: "https://httpbin.org")
    }

    var checkLogin: Bool {
        false
    }
}

// MARK: - Test Validation

struct StandardValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        // 对于 JSONPlaceholder 和 HTTPBin，只要能解析出 NtkResponse 就成功
        return true
    }
}

// MARK: - Custom Data Parsing Interceptor

/// 直接解析响应数据的拦截器
/// 适用于 JSONPlaceholder、HTTPBin 等直接返回 JSON 数据的 API
/// 不期望 `{code, data, msg}` 格式的包装结构
struct DirectDataParsingInterceptor<ResponseData: Decodable & Sendable>: iNtkResponseParser {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)

        // 如果已经是目标类型，直接返回
        if let ntkResponse = response as? NtkResponse<ResponseData> {
            return ntkResponse
        }

        // 期待拿到客户端原始响应
        guard let clientResponse = response as? NtkClientResponse else {
            throw NtkError.invalidResponseType(response: response)
        }
        guard let afRequest = context.request.originalRequest as? iAFRequest else {
            fatalError("request must be iAFRequest type")
        }

        // 兼容两种携带位置：优先使用 response，其次使用 data
        let rawData: Data
        if let d = clientResponse.data as? Data {
            rawData = d
        } else if let d = clientResponse.response as? Data {
            rawData = d
        } else {
            throw NtkError.invalidResponseType(response: response)
        }

        // 日志输出
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: rawData)
            logger.debug(
                """
                ---------------------Direct Response start-------------------------
                \(afRequest)
                参数：\(afRequest.parameters as [String: any Sendable]? ?? [:])
                响应：\(jsonObject)
                ---------------------Direct Response end-------------------------
                """,
                category: .network
            )
        } catch {
            logger.error("response json error \(error)", category: .network)
        }

        do {
            if rawData.isEmpty {
                throw NtkError.responseBodyEmpty(clientResponse: clientResponse)
            }

            // 直接解码为目标类型
            let decoder = JSONDecoder()
            let data = try decoder.decode(ResponseData.self, from: rawData)

            // 构造成功响应，code 设为 0
            return NtkResponse(
                code: NtkReturnCode(0),
                data: data,
                msg: "Success",
                response: clientResponse,
                request: afRequest,
                isCache: clientResponse.isCache
            )
        } catch let error as DecodingError {
            throw NtkError.Serialization.dataDecodingFailed(
                context: .init(
                    clientResponse: clientResponse,
                    recoveredResponse: nil,
                    rawPayload: .data(rawData),
                    underlyingError: error
                )
            )
        } catch {
            throw error
        }
    }
}

// MARK: - Request Modification Fixtures

struct EchoRequestModifier: iNtkRequestModifyingInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addParameter(key: "modifier", value: "applied")
        request.addHeader(key: "X-Request-Modifier", value: "applied")
        request["modifier-source"] = "PodExample"
        return request
    }
}

struct TraceRequestModifier: iNtkRequestModifyingInterceptor {
    let value: String

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        let trace = [request.headers?["X-Modifier-Trace"], value]
            .compactMap { $0 }
            .joined(separator: ",")
        request.addHeader(key: "X-Modifier-Trace", value: trace)
        return request
    }
}

actor ContextFlowProbe {
    private var writerInput: String?
    private var readerInput: String?

    func recordWriterInput(_ value: String?) {
        writerInput = value
    }

    func recordReaderInput(_ value: String?) {
        readerInput = value
    }

    func snapshot() -> (writerInput: String?, readerInput: String?) {
        (writerInput, readerInput)
    }
}

struct ContextWritingInterceptor: iNtkInterceptor {
    let priority: NtkInterceptorPriority = .high
    let probe: ContextFlowProbe

    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        await probe.recordWriterInput(context.extraData["context-trace"] as? String)
        var downstreamContext = context
        downstreamContext.extraData["context-trace"] = "propagated"
        return try await next.handle(context: downstreamContext)
    }
}

struct ContextReadingInterceptor: iNtkInterceptor {
    let priority: NtkInterceptorPriority = .low
    let probe: ContextFlowProbe

    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        await probe.recordReaderInput(context.extraData["context-trace"] as? String)
        return try await next.handle(context: context)
    }
}
