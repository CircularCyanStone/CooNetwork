import Testing
import Foundation
@testable import CooNetwork
@testable import AlamofireClient

struct NtkDataParsingInterceptorTests {

    // MARK: - 已是目标类型直接返回

    @Test
    @NtkActor
    func alreadyTypedResponsePassesThrough() async throws {
        let interceptor = NtkDataParsingInterceptor<Bool, AFTestKeys>()
        let existing = NtkResponse<Bool>(
            code: NtkReturnCode(0), data: true, msg: "ok",
            response: true, request: AFTestRequest(), isCache: false
        )
        let handler = AFTestAlreadyTypedHandler(response: existing)
        let context = makeAFContext()
        let result = try await interceptor.intercept(context: context, next: handler)
        let typed = try #require(result as? NtkResponse<Bool>)
        #expect(typed.data == true)
    }

    // MARK: - NtkNever 类型正常返回

    @Test
    @NtkActor
    func ntkNeverTypeReturnsSuccessfully() async throws {
        let json: [String: Any] = ["retCode": 0, "data": NSNull(), "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<NtkNever, AFTestKeys>()
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        let result = try await interceptor.intercept(context: context, next: handler)
        #expect(result is NtkResponse<NtkNever>)
        #expect(result.code.intValue == 0)
    }

    // MARK: - 常规 Decodable 模型解析

    @Test
    @NtkActor
    func decodableModelParsesCorrectly() async throws {
        let json: [String: Any] = ["retCode": 0, "data": ["id": 1, "name": "test"], "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>()
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        let result = try await interceptor.intercept(context: context, next: handler)
        // 注意：NtkResponseDecoder<ResponseData?, Keys> 导致 data 解码为 ResponseData??
        // if let 解包后 retData 是 ResponseData?，所以返回 NtkResponse<ResponseData?>
        // 这意味着 NtkNetworkExecutor.execute() 中 as? NtkResponse<ResponseData> 会失败
        let typed = try #require(result as? NtkResponse<AFTestModel?>)
        #expect(typed.data?.id == 1)
        #expect(typed.data?.name == "test")
        #expect(typed.code.intValue == 0)
    }

    // MARK: - data 为 nil + validation 通过 → serviceDataEmpty

    @Test
    @NtkActor
    func nilDataWithValidationPassThrowsServiceDataEmpty() async throws {
        let json: [String: Any] = ["retCode": 0, "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>()
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        do {
            _ = try await interceptor.intercept(context: context, next: handler)
            Issue.record("期望抛出 serviceDataEmpty")
        } catch let error as NtkError {
            if case .serviceDataEmpty = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    // MARK: - data 为 nil + validation 失败 → validation 错误

    @Test
    @NtkActor
    func nilDataWithValidationFailThrowsValidationError() async throws {
        let json: [String: Any] = ["retCode": 999, "retMsg": "fail"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>()
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext(validation: AFTestFailValidation())
        do {
            _ = try await interceptor.intercept(context: context, next: handler)
            Issue.record("期望抛出 validation 错误")
        } catch let error as NtkError {
            if case .validation = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    // MARK: - 空响应体 → responseBodyEmpty

    @Test
    @NtkActor
    func emptyResponseBodyThrowsResponseBodyEmpty() async throws {
        let data = Data()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>()
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        do {
            _ = try await interceptor.intercept(context: context, next: handler)
            Issue.record("期望抛出 responseBodyEmpty")
        } catch let error as NtkError {
            if case .responseBodyEmpty = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    // MARK: - JSON 解码失败 → decodeInvalid

    @Test
    @NtkActor
    func invalidJsonThrowsDecodeInvalid() async throws {
        // data 字段类型不匹配：期望对象但给了字符串
        let json: [String: Any] = ["retCode": 0, "data": "not_an_object", "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>()
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        do {
            _ = try await interceptor.intercept(context: context, next: handler)
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case .decodeInvalid = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }
}

// MARK: - Helpers

@NtkActor
private func makeAFContext(validation: iNtkResponseValidation = AFTestPassValidation()) -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(AFTestRequest()),
        validation: validation,
        client: AFTestDummyClient()
    )
}

// MARK: - Test Doubles

private struct AFTestKeys: iNtkResponseMapKeys {
    static let code = "retCode"
    static let data = "data"
    static let msg = "retMsg"
}

private struct AFTestModel: Codable, Sendable {
    let id: Int
    let name: String
}

private struct AFTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/af/test" }
    var method: NtkHTTPMethod { .get }
}

private struct AFTestPassValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct AFTestFailValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { false }
}

private struct AFTestDummyClient: iNtkClient {
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
    }
}

/// 返回已有 NtkResponse 的 handler（用于 already-typed 测试）
@NtkActor
private struct AFTestAlreadyTypedHandler: iNtkRequestHandler {
    let response: any iNtkResponse
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        return response
    }
}

/// 返回携带 Data 的 NtkClientResponse 的 handler
@NtkActor
private struct AFTestDataHandler: iNtkRequestHandler {
    let data: Data
    let request: iNtkRequest
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        return NtkClientResponse(data: data, msg: nil, response: data, request: request, isCache: false)
    }
}
