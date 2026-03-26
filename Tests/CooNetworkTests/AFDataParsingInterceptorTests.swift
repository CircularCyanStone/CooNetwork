import Testing
import Foundation
@testable import CooNetwork
@testable import AlamofireClient

struct NtkDataParsingInterceptorTests {

    // MARK: - 已是目标类型直接返回

    @Test
    @NtkActor
    func alreadyTypedResponsePassesThrough() async throws {
        let interceptor = NtkDataParsingInterceptor<Bool, AFTestKeys>(validation: AFTestPassValidation())
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
        let interceptor = NtkDataParsingInterceptor<NtkNever, AFTestKeys>(validation: AFTestPassValidation())
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
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        let result = try await interceptor.intercept(context: context, next: handler)
        let typed = try #require(result as? NtkResponse<AFTestModel>)
        #expect(typed.data.id == 1)
        #expect(typed.data.name == "test")
        #expect(typed.code.intValue == 0)
    }

    // MARK: - data 为 nil + validation 通过 → serviceDataEmpty

    @Test
    @NtkActor
    func nilDataWithValidationPassThrowsServiceDataEmpty() async throws {
        let json: [String: Any] = ["retCode": 0, "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
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
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestFailValidation())
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
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

    // MARK: - 空响应体 → decodeInvalid

    @Test
    @NtkActor
    func emptyResponseBodyThrowsDecodeInvalid() async throws {
        let data = Data()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        do {
            _ = try await interceptor.intercept(context: context, next: handler)
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case let .decodeInvalid(error) = error {
                #expect(error.response == nil)
                #expect(error.rawValue is Data)
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
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())
        let context = makeAFContext()
        do {
            _ = try await interceptor.intercept(context: context, next: handler)
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case let .decodeInvalid(error) = error {
                let response = try #require(error.response)
                #expect(response.code.intValue == 0)
                #expect(response.msg == "ok")
                #expect(response.data?.getString() == "not_an_object")
                #expect(error.rawValue is Data)
                if let decodingError = error.underlyingError as? DecodingError,
                   case .typeMismatch = decodingError {
                    #expect(Bool(true))
                } else {
                    Issue.record("underlyingError 类型不符: \(error.underlyingError)")
                }
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    // MARK: - decoder 失败路径与 hooks 语义

    @Test
    @NtkActor
    func customDecoderCanExtractHeaderWithRequest() async throws {
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestFailValidation(),
            decoder: AFTestHeaderOnlyDecoder()
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "ok"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFConfiguredTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeConfiguredAFContext(), next: handler)
            Issue.record("期望抛出 validation 错误")
        } catch let error as NtkError {
            if case .validation(_, let response) = error {
                let typed = try #require(response as? NtkResponse<NtkDynamicData?>)
                #expect(typed.code.intValue == 999)
                #expect(typed.msg == "fail")
                #expect(typed.data?["reason"]?.getString() == "mock")
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func decodeFailureWithoutRecoveredHeaderThrowsDecodeInvalid() async throws {
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            decoder: AFTestNoHeaderDecoder()
        )
        let data = try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": ["id": 1, "name": "ok"],
            "retMsg": "ok"
        ])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case let .decodeInvalid(error) = error {
                #expect(error.response == nil)
                #expect(error.rawValue is Data)
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func ntkNeverStillTriggersWillValidateAndDidComplete() async throws {
        let hook = AFTestRecordingHook()
        let json: [String: Any] = ["retCode": 0, "data": NSNull(), "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<NtkNever, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [hook]
        )
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        _ = try await interceptor.intercept(context: makeAFContext(), next: handler)

        #expect(hook.events.contains("didDecodeHeader"))
        #expect(hook.events.contains("willValidate"))
        #expect(hook.events.contains("didComplete"))
    }

    @Test
    @NtkActor
    func transformErrorStopsBeforeDecodeAndHooks() async throws {
        let hook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [hook],
            transformers: [AFTestFailingTransformer()]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "ok"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        await #expect(throws: NtkError.self) {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
        }

        #expect(hook.events.isEmpty)
    }

    @Test
    @NtkActor
    func didCompleteOnlyRunsOnSuccess() async throws {
        let hook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [hook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "ok"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        _ = try await interceptor.intercept(context: makeAFContext(), next: handler)

        #expect(hook.events.contains("didComplete"))
    }

    @Test
    @NtkActor
    func didValidateFailOnlyRunsOnValidationFailure() async throws {
        let hook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestFailValidation(),
            hooks: [hook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 999, "retMsg": "fail"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        await #expect(throws: NtkError.self) {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
        }

        #expect(hook.events.contains("didValidateFail"))
        #expect(!hook.events.contains("didComplete"))
    }

    @Test
    @NtkActor
    func didDecodeHeaderHookErrorDoesNotAbortSuccessfulParse() async throws {
        let throwingHook = AFThrowingHook(throwPoint: .didDecodeHeader)
        let recordingHook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [throwingHook, recordingHook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "test"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        let result = try await interceptor.intercept(context: makeAFContext(), next: handler)
        let typed = try #require(result as? NtkResponse<AFTestModel>)
        #expect(typed.data.id == 1)
        #expect(typed.data.name == "test")
        #expect(throwingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
        #expect(recordingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }

    @Test
    @NtkActor
    func willValidateHookErrorDoesNotAbortSuccessfulParse() async throws {
        let throwingHook = AFThrowingHook(throwPoint: .willValidate)
        let recordingHook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [throwingHook, recordingHook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "test"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        let result = try await interceptor.intercept(context: makeAFContext(), next: handler)
        let typed = try #require(result as? NtkResponse<AFTestModel>)
        #expect(typed.data.id == 1)
        #expect(typed.data.name == "test")
        #expect(throwingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
        #expect(recordingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }

    @Test
    @NtkActor
    func didValidateFailHookErrorDoesNotReplaceValidationError() async throws {
        let throwingHook = AFThrowingHook(throwPoint: .didValidateFail)
        let recordingHook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestFailValidation(),
            hooks: [throwingHook, recordingHook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 999, "retMsg": "fail"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
            Issue.record("期望抛出 validation 错误")
        } catch let error as NtkError {
            if case .validation = error {
                #expect(throwingHook.events == ["didDecodeHeader", "willValidate", "didValidateFail"])
                #expect(recordingHook.events == ["didDecodeHeader", "willValidate", "didValidateFail"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func didCompleteHookErrorDoesNotReplaceSuccessfulResult() async throws {
        let throwingHook = AFThrowingHook(throwPoint: .didComplete)
        let recordingHook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [throwingHook, recordingHook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "test"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        let result = try await interceptor.intercept(context: makeAFContext(), next: handler)
        let typed = try #require(result as? NtkResponse<AFTestModel>)
        #expect(typed.code.intValue == 0)
        #expect(typed.data.id == 1)
        #expect(throwingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
        #expect(recordingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }

    @Test
    @NtkActor
    func dataNullBehavesSameAsMissingData() async throws {
        let json: [String: Any] = ["retCode": 0, "data": NSNull(), "retMsg": "ok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
            Issue.record("期望抛出 serviceDataEmpty")
        } catch let error as NtkError {
            if case .serviceDataEmpty = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func topLevelObjectWithDefaultDataDecoderThrowsTypeMismatch() async throws {
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
        let rawObject: [String: any Sendable] = [
            "retCode": 0,
            "retMsg": "ok",
            "data": ["id": 1, "name": "test"] as [String: any Sendable]
        ]
        let handler = AFTestRawClientResponseHandler(raw: rawObject, request: AFTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
            Issue.record("期望抛出 typeMismatch")
        } catch let error as NtkError {
            if case .typeMismatch = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func topLevelArrayWithDefaultDataDecoderFailsWithoutRecoveredHeader() async throws {
        let hook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [hook]
        )
        let rawArray: [any Sendable] = [
            ["id": 1, "name": "a"] as [String: any Sendable],
            ["id": 2, "name": "b"] as [String: any Sendable]
        ]
        let handler = AFTestRawClientResponseHandler(raw: rawArray, request: AFTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
            Issue.record("期望抛出 typeMismatch")
        } catch let error as NtkError {
            if case .typeMismatch = error {
                #expect(hook.events.isEmpty)
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func topLevelScalarPayloadIsRejectedAtNormalizeBoundary() async throws {
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(validation: AFTestPassValidation())
        let handler = AFTestRawClientResponseHandler(raw: "ok", request: AFTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeAFContext(), next: handler)
            Issue.record("期望抛出 typeMismatch")
        } catch let error as NtkError {
            if case .typeMismatch = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func decodeFailureWithHeaderDoesNotTriggerDidDecodeHeaderOrDidComplete() async throws {
        let hook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [hook],
            decoder: AFTestHeaderOnlyDecoder()
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "ok"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFConfiguredTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeConfiguredAFContext(), next: handler)
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case let .decodeInvalid(error) = error {
                let response = try #require(error.response)
                #expect(response.code.intValue == 999)
                #expect(response.msg == "fail")
                #expect(response.data?["reason"]?.getString() == "mock")
                #expect(hook.events == ["willValidate"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func decodeFailureWithHeaderValidationFailureTriggersDidValidateFailOnly() async throws {
        let hook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestFailValidation(),
            hooks: [hook],
            decoder: AFTestHeaderOnlyDecoder()
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "ok"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFConfiguredTestRequest())

        do {
            _ = try await interceptor.intercept(context: makeConfiguredAFContext(), next: handler)
            Issue.record("期望抛出 validation 错误")
        } catch let error as NtkError {
            if case .validation = error {
                #expect(hook.events == ["willValidate", "didValidateFail"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func transformerCanConvertDataPayloadToDynamicObjectForJSONObjectDecoder() async throws {
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            transformers: [AFDataToJSONObjectTransformer()],
            decoder: NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()
        )
        let data = try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "retMsg": "ok",
            "data": ["id": 1, "name": "test"]
        ])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        let result = try await interceptor.intercept(context: makeAFContext(), next: handler)
        let typed = try #require(result as? NtkResponse<AFTestModel>)
        #expect(typed.code.intValue == 0)
        #expect(typed.data.id == 1)
        #expect(typed.data.name == "test")
    }
    @Test
    @NtkActor
    func throwingHookDoesNotBlockLaterHooksOnSameNotification() async throws {
        let throwingHook = AFThrowingHook(throwPoint: .willValidate)
        let recordingHook = AFTestRecordingHook()
        let interceptor = NtkDataParsingInterceptor<AFTestModel, AFTestKeys>(
            validation: AFTestPassValidation(),
            hooks: [throwingHook, recordingHook]
        )
        let data = try JSONSerialization.data(withJSONObject: ["retCode": 0, "data": ["id": 1, "name": "test"], "retMsg": "ok"])
        let handler = AFTestDataHandler(data: data, request: AFTestRequest())

        _ = try await interceptor.intercept(context: makeAFContext(), next: handler)

        #expect(throwingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
        #expect(recordingHook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }
}

// MARK: - Helpers

@NtkActor
private func makeAFContext() -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(AFTestRequest()),
        client: AFTestDummyClient()
    )
}

@NtkActor
private func makeConfiguredAFContext() -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(AFConfiguredTestRequest()),
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

private struct AFConfiguredTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/af/test/configured" }
    var method: NtkHTTPMethod { .get }
    var requestConfiguration: NtkRequestConfiguration? { .default() }
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

private enum AFHookThrowPoint: Equatable {
    case didDecodeHeader
    case willValidate
    case didValidateFail
    case didComplete
}

private struct AFHookObserverError: Error, Equatable {
    let point: AFHookThrowPoint
}

private final class AFThrowingHook: iNtkParsingHooks, @unchecked Sendable {
    let throwPoint: AFHookThrowPoint
    var events: [String] = []

    init(throwPoint: AFHookThrowPoint) {
        self.throwPoint = throwPoint
    }

    func didDecodeHeader(retCode: Int, msg: String?, context: NtkInterceptorContext) async throws {
        events.append("didDecodeHeader")
        if throwPoint == .didDecodeHeader {
            throw AFHookObserverError(point: .didDecodeHeader)
        }
    }

    func willValidate(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("willValidate")
        if throwPoint == .willValidate {
            throw AFHookObserverError(point: .willValidate)
        }
    }

    func didValidateFail(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didValidateFail")
        if throwPoint == .didValidateFail {
            throw AFHookObserverError(point: .didValidateFail)
        }
    }

    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didComplete")
        if throwPoint == .didComplete {
            throw AFHookObserverError(point: .didComplete)
        }
    }
}

private final class AFTestRecordingHook: iNtkParsingHooks, @unchecked Sendable {
    var events: [String] = []

    func didDecodeHeader(retCode: Int, msg: String?, context: NtkInterceptorContext) async throws {
        events.append("didDecodeHeader")
    }

    func willValidate(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("willValidate")
    }

    func didValidateFail(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didValidateFail")
    }

    func didComplete(_ response: any iNtkResponse, context: NtkInterceptorContext) async throws {
        events.append("didComplete")
    }
}

private struct AFTestFailingTransformer: iNtkResponsePayloadTransforming {
    func transform(_ payload: NtkPayload, context: NtkInterceptorContext) async throws -> NtkPayload {
        throw NtkError.typeMismatch
    }
}

private struct AFTestHeaderOnlyDecoder: iNtkResponsePayloadDecoding {
    func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<AFTestModel, AFTestKeys> {
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "expected failure for header extraction")
        )
    }

    func extractHeader(_ payload: NtkPayload, request: iNtkRequest) throws -> NtkExtractedHeader? {
        guard request.requestConfiguration != nil else { return nil }
        return NtkExtractedHeader(
            code: NtkReturnCode(999),
            msg: "fail",
            data: NtkDynamicData(dictionary: ["reason": "mock"])
        )
    }
}

private struct AFTestNoHeaderDecoder: iNtkResponsePayloadDecoding {
    func decode(
        _ payload: NtkPayload,
        context: NtkInterceptorContext
    ) async throws -> NtkResponseDecoder<AFTestModel, AFTestKeys> {
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "expected failure without header extraction")
        )
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

@NtkActor
private struct AFTestRawClientResponseHandler: iNtkRequestHandler {
    let raw: any Sendable
    let request: iNtkRequest
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        NtkClientResponse(data: raw, msg: nil, response: raw, request: request, isCache: false)
    }
}

private struct AFDataToJSONObjectTransformer: iNtkResponsePayloadTransforming {
    func transform(_ payload: NtkPayload, context: NtkInterceptorContext) async throws -> NtkPayload {
        guard case .data(let data) = payload else {
            throw NtkError.typeMismatch
        }
        let raw = try JSONSerialization.jsonObject(with: data)
        return try NtkPayload.normalize(from: raw)
    }
}
