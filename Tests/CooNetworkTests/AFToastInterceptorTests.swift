import Foundation
import Testing

@testable import AlamofireClient
@testable import CooNetwork

struct AFToastInterceptorTests {
    @Test
    @NtkActor
    func validationErrorShowsResponseMessage() async throws {
        let recorder = ToastRecorder()
        let interceptor = AFToastInterceptor(toastHandler: recorder.record)
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(ToastTestRequest()),
            client: ToastDummyClient()
        )

        do {
            _ = try await interceptor.intercept(context: context, next: ToastValidationFailureHandler())
            Issue.record("期望抛出 validation 错误")
        } catch let error as NtkError.Validation {
            if case .serviceRejected = error {
                #expect(recorder.messages() == ["业务失败"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func ignoredValidationCodeDoesNotShowToast() async throws {
        let recorder = ToastRecorder()
        let interceptor = AFToastInterceptor(ignoreCode: [401], toastHandler: recorder.record)
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(ToastTestRequest()),
            client: ToastDummyClient()
        )

        do {
            _ = try await interceptor.intercept(context: context, next: ToastIgnoredValidationFailureHandler())
            Issue.record("期望抛出 validation 错误")
        } catch let error as NtkError.Validation {
            if case .serviceRejected = error {
                #expect(recorder.messages().isEmpty)
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func timeoutShowsTimeoutToast() async throws {
        let recorder = ToastRecorder()
        let interceptor = AFToastInterceptor(toastHandler: recorder.record)
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(ToastTestRequest()),
            client: ToastDummyClient()
        )

        do {
            _ = try await interceptor.intercept(context: context, next: ToastTimeoutHandler())
            Issue.record("期望抛出 timeout")
        } catch let error as NtkError {
            if case .requestTimeout = error {
                #expect(recorder.messages() == ["连接超时~"])
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func clientErrorShowsSystemMessage() async throws {
        let recorder = ToastRecorder()
        let interceptor = AFToastInterceptor(toastHandler: recorder.record)
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(ToastTestRequest()),
            client: ToastDummyClient()
        )

        do {
            _ = try await interceptor.intercept(context: context, next: ToastClientErrorHandler())
            Issue.record("期望抛出 client error")
        } catch let error as NtkError.Client {
            if case .external = error {
                let messages = recorder.messages()
                #expect(messages.count == 1)
                #expect(messages[0].contains("The operation couldn’t be completed") || messages[0].contains("timed out") || messages[0].contains("超时"))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }
}

private final class ToastRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func record(_ message: String) {
        lock.lock()
        values.append(message)
        lock.unlock()
    }

    func messages() -> [String] {
        lock.lock()
        let snapshot = values
        lock.unlock()
        return snapshot
    }
}

private struct ToastTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/toast/test" }
    var method: NtkHTTPMethod { .get }
}

private struct ToastDummyClient: iNtkClient {
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
    }
}

@NtkActor
private struct ToastValidationFailureHandler: iNtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        throw NtkError.Validation.serviceRejected(
            request: ToastTestRequest(),
            response: NtkResponse<Bool>(
                code: NtkReturnCode(999),
                data: false,
                msg: "业务失败",
                response: false,
                request: ToastTestRequest(),
                isCache: false
            )
        )
    }
}

@NtkActor
private struct ToastIgnoredValidationFailureHandler: iNtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        throw NtkError.Validation.serviceRejected(
            request: ToastTestRequest(),
            response: NtkResponse<Bool>(
                code: NtkReturnCode(401),
                data: false,
                msg: "忽略我",
                response: false,
                request: ToastTestRequest(),
                isCache: false
            )
        )
    }
}

@NtkActor
private struct ToastTimeoutHandler: iNtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        throw NtkError.requestTimeout
    }
}

@NtkActor
private struct ToastClientErrorHandler: iNtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        throw NtkError.Client.external(
            reason: NtkError.Client.AF.requestFailed,
            request: ToastTestRequest(),
            clientResponse: nil,
            underlyingError: URLError(.timedOut),
            message: URLError(.timedOut).localizedDescription
        )
    }
}
