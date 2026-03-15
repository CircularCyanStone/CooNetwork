import Testing
import Foundation
@testable import CooNetwork

struct NtkRetryInterceptorTests {
    @Test
    @NtkActor
    func zeroRetryShouldThrowTypedErrorInsteadOfCrash() async {
        let interceptor = NtkRetryInterceptor(retryPolicy: ZeroRetryPolicy())
        let context = NtkInterceptorContext(
            mutableRequest: NtkMutableRequest(DummyRequest()),
            validation: DummyValidation(),
            client: DummyClient()
        )
        
        do {
            _ = try await interceptor.intercept(context: context, next: AlwaysFailHandler())
            Issue.record("期望抛出错误，但实际未抛出")
        } catch let error as NtkError {
            switch error {
            case .requestTimeout:
                #expect(Bool(true))
            default:
                Issue.record("抛出了错误类型，但不是 requestTimeout: \(error)")
            }
        } catch {
            Issue.record("抛出了未知错误类型: \(error)")
        }
    }
}

private struct ZeroRetryPolicy: iNtkRetryPolicy {
    let maxRetryCount: Int = 0
    
    func retryDelay(for attemptCount: Int, error: Error) -> TimeInterval? {
        nil
    }
    
    func shouldRetry(attemptCount: Int, error: Error) -> Bool {
        false
    }
}

private struct DummyRequest: iNtkRequest {
    var path: String { "/retry/test" }
}

private struct DummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        true
    }
}

private struct DummyKeys: iNtkResponseMapKeys {
    static let code: String = "code"
    static let data: String = "data"
    static let msg: String = "msg"
}

private struct DummyClient: iNtkClient {
    typealias Keys = DummyKeys
    
    var storage: any iNtkCacheStorage {
        DummyCacheStorage()
    }
    
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        throw NtkError.requestTimeout
    }
    
    @NtkActor
    func loadCache(_ request: NtkMutableRequest) async throws -> NtkClientResponse? {
        nil
    }
    
    @NtkActor
    func saveCache(_ request: NtkMutableRequest, response: Sendable) async -> Bool {
        false
    }
    
    @NtkActor
    func hasCacheData(_ request: NtkMutableRequest) async -> NtkResponse<Bool> {
        NtkResponse(
            code: NtkReturnCode(200),
            data: false,
            msg: nil,
            response: false,
            request: request,
            isCache: true
        )
    }
}

private struct DummyCacheStorage: iNtkCacheStorage {
    @NtkActor
    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }
    
    @NtkActor
    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        nil
    }
    
    @NtkActor
    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }
}

@NtkActor
private struct AlwaysFailHandler: NtkRequestHandler {
    func handle(context: NtkInterceptorContext) async throws -> any iNtkResponse {
        throw NtkError.requestTimeout
    }
}
