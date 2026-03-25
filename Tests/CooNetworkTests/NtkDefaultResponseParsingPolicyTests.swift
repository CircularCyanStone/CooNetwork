import Testing
import Foundation
@testable import CooNetwork
@testable import AlamofireClient

struct NtkDefaultResponseParsingPolicyTests {

    @Test
    @NtkActor
    func decodedResultWithDataReturnsTypedResponseAndDidComplete() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestPassValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        let result = try await policy.decide(
            from: .decoded(
                code: NtkReturnCode(0),
                msg: "ok",
                data: PolicyTestModel(id: 1, name: "test"),
                request: PolicyTestRequest(),
                clientResponse: makePolicyClientResponse(),
                isCache: false
            ),
            context: makePolicyContext()
        )

        let typed = try #require(result as? NtkResponse<PolicyTestModel>)
        #expect(typed.code.intValue == 0)
        #expect(typed.data.id == 1)
        #expect(typed.data.name == "test")
        #expect(hook.events == ["willValidate", "didComplete"])
    }

    @Test
    @NtkActor
    func decodedResultWithNilDataAndValidationPassThrowsServiceDataEmpty() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestPassValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        do {
            _ = try await policy.decide(
                from: .decoded(
                    code: NtkReturnCode(0),
                    msg: "ok",
                    data: nil,
                    request: PolicyTestRequest(),
                    clientResponse: makePolicyClientResponse(),
                    isCache: false
                ),
                context: makePolicyContext()
            )
            Issue.record("期望抛出 serviceDataEmpty")
        } catch let error as NtkError {
            if case .serviceDataEmpty = error {
                #expect(hook.events == ["willValidate"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func decodedResultWithNilDataAndValidationFailThrowsValidation() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestFailValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        do {
            _ = try await policy.decide(
                from: .decoded(
                    code: NtkReturnCode(999),
                    msg: "fail",
                    data: nil,
                    request: PolicyTestRequest(),
                    clientResponse: makePolicyClientResponse(),
                    isCache: false
                ),
                context: makePolicyContext()
            )
            Issue.record("期望抛出 validation")
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
    func decodedResultWithNtkNeverReturnsSuccess() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<NtkNever>(
            validation: PolicyTestPassValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        let result = try await policy.decide(
            from: .decoded(
                code: NtkReturnCode(0),
                msg: "ok",
                data: nil,
                request: PolicyTestRequest(),
                clientResponse: makePolicyClientResponse(),
                isCache: false
            ),
            context: makePolicyContext()
        )

        let typed = try #require(result as? NtkResponse<NtkNever>)
        #expect(typed.code.intValue == 0)
        #expect(hook.events == ["willValidate", "didComplete"])
    }

    @Test
    @NtkActor
    func headerRecoveredWithValidationFailThrowsValidation() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestFailValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        do {
            _ = try await policy.decide(
                from: makeHeaderRecoveredResult(),
                context: makePolicyContext()
            )
            Issue.record("期望抛出 validation")
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
    func headerRecoveredWithValidationPassStillThrowsDecodeInvalid() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestPassValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        do {
            _ = try await policy.decide(
                from: makeHeaderRecoveredResult(),
                context: makePolicyContext()
            )
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case .decodeInvalid = error {
                #expect(hook.events == ["willValidate"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func unrecoverableDecodeFailureThrowsDecodeInvalid() async throws {
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestPassValidation(),
            dispatcher: NtkParsingHookDispatcher()
        )

        do {
            _ = try await policy.decide(
                from: .unrecoverableDecodeFailure(
                    decodeError: makePolicyDecodeError(),
                    rawPayload: .data(Data("{}".utf8)),
                    request: PolicyTestRequest(),
                    clientResponse: makePolicyClientResponse(),
                    isCache: false
                ),
                context: makePolicyContext()
            )
            Issue.record("期望抛出 decodeInvalid")
        } catch let error as NtkError {
            if case .decodeInvalid = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func headerRecoveredDoesNotTriggerDidComplete() async throws {
        let hook = PolicyTestRecordingHook()
        let policy = NtkDefaultResponseParsingPolicy<PolicyTestModel>(
            validation: PolicyTestPassValidation(),
            dispatcher: NtkParsingHookDispatcher(hooks: [hook])
        )

        await #expect(throws: NtkError.self) {
            _ = try await policy.decide(
                from: makeHeaderRecoveredResult(),
                context: makePolicyContext()
            )
        }

        #expect(!hook.events.contains("didComplete"))
    }
}

private struct PolicyTestModel: Codable, Sendable {
    let id: Int
    let name: String
}

private struct PolicyTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/policy/test" }
    var method: NtkHTTPMethod { .get }
}

private struct PolicyTestPassValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct PolicyTestFailValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { false }
}

private final class PolicyTestRecordingHook: iNtkParsingHooks, @unchecked Sendable {
    var events: [String] = []

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

@NtkActor
private func makePolicyContext() -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(PolicyTestRequest()),
        client: PolicyTestDummyClient()
    )
}

private func makePolicyClientResponse() -> NtkClientResponse {
    NtkClientResponse(
        data: Data("{}".utf8),
        msg: nil,
        response: Data("{}".utf8),
        request: PolicyTestRequest(),
        isCache: false
    )
}

private func makeHeaderRecoveredResult() -> NtkParsingResult<PolicyTestModel> {
    .headerRecovered(
        decodeError: makePolicyDecodeError(),
        rawPayload: .dynamic(NtkDynamicData(dictionary: [
            "retCode": 999,
            "retMsg": "fail",
            "data": ["reason": "mock"]
        ])),
        header: NtkExtractedHeader(
            code: NtkReturnCode(999),
            msg: "fail",
            data: NtkDynamicData(dictionary: ["reason": "mock"])
        ),
        request: PolicyTestRequest(),
        clientResponse: makePolicyClientResponse(),
        isCache: false
    )
}

private func makePolicyDecodeError() -> DecodingError {
    .typeMismatch(
        PolicyTestModel.self,
        .init(codingPath: [], debugDescription: "expected failure")
    )
}

private struct PolicyTestDummyClient: iNtkClient {
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        makePolicyClientResponse()
    }
}
