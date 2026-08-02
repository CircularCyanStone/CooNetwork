import Foundation
import XCTest
import CooNetwork

final class CooNetworkPublicAPITests: XCTestCase {

    func testRequestModifierUpdatesRequestBeforeClientExecution() async throws {
        let recorder = RequestRecorder()
        let network = makeNetwork(
            client: RecordingClient(recorder: recorder),
            request: FixtureRequest(
                path: "/modifier",
                headers: ["X-Original": "original"],
                parameters: ["original": "value"]
            )
        )
        network.addInterceptor(RequestEnrichmentModifier())

        _ = try await network.request()

        let snapshots = await recorder.snapshots()
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(snapshot.headers["X-Original"], "original")
        XCTAssertEqual(snapshot.headers["X-Modified"], "true")
        XCTAssertEqual(snapshot.parameters["original"] as? String, "value")
        XCTAssertEqual(snapshot.parameters["modified"] as? String, "value")
        XCTAssertEqual(snapshot.requestExtraData["source"] as? String, "modifier")
    }

    func testRequestModifiersPreserveRegistrationOrderAtEqualPriority() async throws {
        let recorder = RequestRecorder()
        let network = makeNetwork(
            client: RecordingClient(recorder: recorder),
            request: FixtureRequest(path: "/ordering")
        )
        network.addInterceptor(TraceModifier(value: "first"))
        network.addInterceptor(TraceModifier(value: "second"))

        _ = try await network.request()

        let snapshots = await recorder.snapshots()
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(snapshot.headers["X-Modifier-Trace"], "first,second")
    }

    func testThrowingRequestModifierStopsBeforeClientExecution() async throws {
        let recorder = RequestRecorder()
        let network = makeNetwork(
            client: RecordingClient(recorder: recorder),
            request: FixtureRequest(path: "/modifier-error")
        )
        network.addInterceptor(ThrowingModifier())

        do {
            _ = try await network.request()
            XCTFail("请求修改器抛错后不应继续执行客户端")
        } catch FixtureError.modificationFailed {
            // Expected.
        } catch {
            XCTFail("收到非预期错误: \(error)")
        }

        let recordedRequestCount = await recorder.snapshots().count
        XCTAssertEqual(recordedRequestCount, 0)
    }

    func testContextExtraDataFlowsOnlyThroughDownstreamCopy() async throws {
        let requestRecorder = RequestRecorder()
        let contextRecorder = ContextRecorder()
        let network = makeNetwork(
            client: RecordingClient(recorder: requestRecorder),
            request: FixtureRequest(path: "/context"),
            responseParser: ContextRecordingParser(recorder: contextRecorder)
        )
        network.addInterceptor(ContextValueWriter(recorder: contextRecorder))

        _ = try await network.request()

        let values = await contextRecorder.values()
        XCTAssertNil(values.writerInputValue)
        XCTAssertEqual(values.parserValue, "downstream")
        XCTAssertEqual(values.parserPath, "/context")
    }

    func testParsingHooksReceiveModifiedRequestAndContextSnapshots() async throws {
        let hook = ParsingHookRecorder()
        let data = try JSONSerialization.data(withJSONObject: [
            "code": 0,
            "data": true,
            "message": "ok"
        ])
        let network = NtkNetwork<Bool>.with(
            JSONClient(data: data),
            request: FixtureRequest(path: "/parsing-context"),
            responseParser: NtkDataParsingInterceptor<Bool, FixtureResponseKeys>(
                validation: AlwaysValidResponse(),
                hooks: [hook]
            )
        )
        network.addInterceptor(RequestMarkerModifier())
        network.addInterceptor(ParsingContextValueWriter())

        let response = try await network.request()

        let recordedSnapshot = await hook.snapshot()
        let snapshot = try XCTUnwrap(recordedSnapshot)
        XCTAssertTrue(response.data)
        XCTAssertEqual(snapshot.path, "/parsing-context")
        XCTAssertEqual(snapshot.requestValue, "request-snapshot")
        XCTAssertEqual(snapshot.contextValue, "context-snapshot")
    }

    func testCacheAndNetworkBuildIndependentRequestsFromInitialSnapshot() async throws {
        let modifierCounter = ModifierCounter()
        let storage = FixedCacheStorage(value: true)
        let network = NtkNetwork<Bool>.with(
            RecordingClient(recorder: RequestRecorder()),
            request: FixtureRequest(path: "/cache", requestConfiguration: .default()),
            responseParser: BoolResponseParser(),
            interceptors: [NtkCacheInterceptor(storage: storage)]
        )
        network.addInterceptor(CountingModifier(counter: modifierCounter))

        let loadedCacheResponse = try await network.loadCache()
        let cachedResponse = try XCTUnwrap(loadedCacheResponse)
        let networkResponse = try await network.request()

        XCTAssertEqual(cachedResponse.request.headers?["X-Modification-Count"], "1")
        XCTAssertEqual(networkResponse.request.headers?["X-Modification-Count"], "1")
        let modifierCallCount = await modifierCounter.value()
        XCTAssertEqual(modifierCallCount, 2)
    }

    func testIndependentNetworksExecuteConcurrentlyWithoutGlobalActorIsolation() async throws {
        let recorder = RequestRecorder()

        let paths = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<20 {
                group.addTask {
                    let network = makeNetwork(
                        client: RecordingClient(recorder: recorder),
                        request: FixtureRequest(path: "/concurrent/\(index)")
                    )
                    let response = try await network.request()
                    return response.request.path
                }
            }

            var paths: Set<String> = []
            for try await path in group {
                paths.insert(path)
            }
            return paths
        }

        XCTAssertEqual(paths.count, 20)
        let recordedRequestCount = await recorder.snapshots().count
        XCTAssertEqual(recordedRequestCount, 20)
    }
}

private func makeNetwork(
    client: any iNtkClient,
    request: FixtureRequest,
    responseParser: any iNtkResponseParser = BoolResponseParser()
) -> NtkNetwork<Bool> {
    NtkNetwork<Bool>.with(
        client,
        request: request,
        responseParser: responseParser
    )
}

private struct FixtureRequest: iNtkRequest {
    let path: String
    var headers: [String: String]?
    var parameters: [String: Sendable]?
    var requestConfiguration: NtkRequestConfiguration?

    init(
        path: String,
        headers: [String: String]? = nil,
        parameters: [String: Sendable]? = nil,
        requestConfiguration: NtkRequestConfiguration? = nil
    ) {
        self.path = path
        self.headers = headers
        self.parameters = parameters
        self.requestConfiguration = requestConfiguration
    }
}

private struct RequestSnapshot: Sendable {
    let path: String
    let headers: [String: String]
    let parameters: [String: Sendable]
    let requestExtraData: [String: Sendable]
}

private actor RequestRecorder {
    private var recordedSnapshots: [RequestSnapshot] = []

    func record(_ request: NtkMutableRequest) {
        recordedSnapshots.append(
            RequestSnapshot(
                path: request.path,
                headers: request.headers ?? [:],
                parameters: request.parameters ?? [:],
                requestExtraData: request.extraData
            )
        )
    }

    func snapshots() -> [RequestSnapshot] {
        recordedSnapshots
    }
}

private struct RecordingClient: iNtkClient {
    let recorder: RequestRecorder

    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        await recorder.record(request)
        return NtkClientResponse(
            data: true,
            msg: "ok",
            response: true,
            request: request,
            isCache: false
        )
    }
}

private struct JSONClient: iNtkClient {
    let data: Data

    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(
            data: data,
            msg: "ok",
            response: data,
            request: request,
            isCache: false
        )
    }
}

private struct BoolResponseParser: iNtkResponseParser {
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        return NtkResponse(
            code: NtkReturnCode(0),
            data: (response.data as? Bool) ?? true,
            msg: response.msg,
            response: response.response,
            request: response.request,
            isCache: response.isCache
        )
    }
}

private struct RequestEnrichmentModifier: iNtkRequestModifyingInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.addHeader(key: "X-Modified", value: "true")
        request.addParameter(key: "modified", value: "value")
        request["source"] = "modifier"
        return request
    }
}

private struct TraceModifier: iNtkRequestModifyingInterceptor {
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

private enum FixtureError: Error {
    case modificationFailed
}

private struct ThrowingModifier: iNtkRequestModifyingInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        throw FixtureError.modificationFailed
    }
}

private actor ContextRecorder {
    private var writerInputValue: String?
    private var parserValue: String?
    private var parserPath: String?

    func recordWriterInput(_ value: String?) {
        writerInputValue = value
    }

    func recordParser(value: String?, path: String) {
        parserValue = value
        parserPath = path
    }

    func values() -> (writerInputValue: String?, parserValue: String?, parserPath: String?) {
        (writerInputValue, parserValue, parserPath)
    }
}

private struct ContextValueWriter: iNtkInterceptor {
    let recorder: ContextRecorder

    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        await recorder.recordWriterInput(context.extraData["trace"] as? String)
        var downstreamContext = context
        downstreamContext.extraData["trace"] = "downstream"
        return try await next.handle(context: downstreamContext)
    }
}

private struct ContextRecordingParser: iNtkResponseParser {
    let recorder: ContextRecorder

    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        await recorder.recordParser(
            value: context.extraData["trace"] as? String,
            path: context.request.path
        )
        return try await BoolResponseParser().intercept(context: context, next: next)
    }
}

private struct RequestMarkerModifier: iNtkRequestModifyingInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request["request-marker"] = "request-snapshot"
        return request
    }
}

private struct ParsingContextValueWriter: iNtkInterceptor {
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        var downstreamContext = context
        downstreamContext.extraData["context-marker"] = "context-snapshot"
        return try await next.handle(context: downstreamContext)
    }
}

private struct ParsingSnapshot: Sendable {
    let path: String
    let requestValue: String?
    let contextValue: String?
}

private actor ParsingHookRecorder: iNtkParsingHooks {
    private var recordedSnapshot: ParsingSnapshot?

    func didComplete(
        _ response: any iNtkResponse,
        context: NtkParsingContext
    ) async throws {
        recordedSnapshot = ParsingSnapshot(
            path: context.request.path,
            requestValue: context.request.extraData["request-marker"] as? String,
            contextValue: context.extraData["context-marker"] as? String
        )
    }

    func snapshot() -> ParsingSnapshot? {
        recordedSnapshot
    }
}

private struct FixtureResponseKeys: iNtkResponseMapKeys {
    static let code = "code"
    static let data = "data"
    static let msg = "message"
}

private struct AlwaysValidResponse: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        true
    }
}

private actor ModifierCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }

    func value() -> Int {
        count
    }
}

private struct CountingModifier: iNtkRequestModifyingInterceptor {
    let counter: ModifierCounter

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        _ = await counter.increment()
        var request = request
        let previousValue = Int(request.headers?["X-Modification-Count"] ?? "") ?? 0
        request.addHeader(
            key: "X-Modification-Count",
            value: String(previousValue + 1)
        )
        return request
    }
}

private struct FixedCacheStorage: iNtkCacheStorage {
    let value: any Sendable

    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }

    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        NtkCacheMeta(
            appVersion: "1.0",
            creationDate: Date().timeIntervalSince1970,
            expirationDate: Date().timeIntervalSince1970 + 3_600,
            data: value
        )
    }

    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        true
    }
}
