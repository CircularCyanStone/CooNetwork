import Foundation
import Testing
import Alamofire

@testable import AlamofireClient
@testable import CooNetwork

@Suite(.serialized)
struct NtkAFConfigurationTests {

    @Test
    func defaultConfigurationBuildsTheLongTermEntry() {
        let _: NtkAFConfiguration<NtkAFConfigurationTestModel> = .default
        let network = NtkAF<NtkAFConfigurationTestModel>.alamofire(
            NtkAFConfigurationTestRequest()
        )

        #expect(network.mutableRequest.path == "/configuration")
    }

    @Test
    func standardStrategyUsesInjectedClientTransformerDecoderAndHooks() async throws {
        let session = makeNtkAFConfigurationTestSession(
            body: Data(#"{"retCode":0,"data":{"id":7},"retMsg":"ok"}"#.utf8)
        )
        let events = NtkAFConfigurationEventRecorder()
        let configuration = NtkAFConfiguration<NtkAFConfigurationTestModel>(
            client: AFClient(session: session),
            parsing: .standard(
                keys: NtkAFConfigurationTestKeys.self,
                validation: NtkAFConfigurationPassingValidation(),
                hooks: [NtkAFConfigurationRecordingHook(events: events)],
                transformers: [NtkAFConfigurationDataToObjectTransformer(events: events)],
                decoder: NtkJSONObjectPayloadDecoder<
                    NtkAFConfigurationTestModel,
                    NtkAFConfigurationTestKeys
                >()
            )
        )

        let response = try await NtkAF<NtkAFConfigurationTestModel>.alamofire(
            NtkAFConfigurationTestRequest(),
            configuration: configuration
        ).request()

        #expect(response.data.id == 7)
        #expect(await events.snapshot() == ["transform", "decoded", "completed"])
    }

    @Test
    func standardStrategyUsesDefaultResponseKeysAndDataDecoder() async throws {
        let session = makeNtkAFConfigurationTestSession(
            body: Data(#"{"retCode":0,"data":{"id":8},"retMsg":"ok"}"#.utf8)
        )
        let configuration = NtkAFConfiguration<NtkAFConfigurationTestModel>(
            client: AFClient(session: session)
        )

        let response = try await NtkAF<NtkAFConfigurationTestModel>.alamofire(
            NtkAFConfigurationTestRequest(),
            configuration: configuration
        ).request()

        #expect(response.data.id == 8)
    }

    @Test
    func customStrategyCompletelyReplacesTheStandardParser() async throws {
        let configuration = NtkAFConfiguration<NtkAFConfigurationTestModel>(
            parsing: .custom(NtkAFConfigurationCustomParser())
        )

        let response = try await NtkAF<NtkAFConfigurationTestModel>.alamofire(
            NtkAFConfigurationTestRequest(),
            configuration: configuration
        ).request()

        #expect(response.data.id == 99)
    }

    @Test
    func configurationInjectsCacheStorage() async {
        let configuration = NtkAFConfiguration<Bool>(
            parsing: .custom(NtkAFConfigurationBoolCustomParser()),
            cacheStorage: NtkAFConfigurationCacheStorage()
        )
        let network = NtkAFBool.alamofire(
            NtkAFConfigurationCacheRequest(),
            configuration: configuration
        )

        #expect(await network.hasCacheData())
    }

    @Test
    func uploadRequestsDisableDeduplicationThroughTheNewEntry() {
        let network = NtkAF<NtkNever>.alamofire(NtkAFConfigurationUploadRequest())

        switch network.mutableRequest.deduplicationPolicy {
        case .disabled:
            break
        case .inherit, .enabled:
            Issue.record("Alamofire 上传请求应默认禁用去重")
        }
    }

    @available(*, deprecated)
    @Test
    func legacyOverloadsRemainSourceCompatibleDuringMigration() {
        let request = NtkAFConfigurationTestRequest()
        let defaultKeys = NtkAF<NtkAFConfigurationTestModel>.withAF(request)
        let customKeys = NtkAF<NtkAFConfigurationTestModel>.withAF(
            request,
            keys: NtkAFConfigurationTestKeys.self
        )

        #expect(defaultKeys.mutableRequest.path == request.path)
        #expect(customKeys.mutableRequest.path == request.path)
    }

    @available(*, deprecated)
    @Test
    func legacyEntryKeepsRequestProvidedValidationFallback() async {
        let network = NtkAF<NtkAFConfigurationTestModel>.withAF(
            NtkAFConfigurationLegacyValidationRequest(),
            storage: NtkAFConfigurationLegacyCacheStorage()
        )

        await #expect(throws: NtkError.Validation.self) {
            _ = try await network.loadCache()
        }
    }
}

private struct NtkAFConfigurationTestModel: Codable, Sendable {
    let id: Int
}

private struct NtkAFConfigurationTestKeys: iNtkResponseMapKeys {
    static let code = "retCode"
    static let data = "data"
    static let msg = "retMsg"
}

private struct NtkAFConfigurationTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://configuration.test") }
    var path: String { "/configuration" }
    var method: NtkHTTPMethod { .get }
}

private struct NtkAFConfigurationCacheRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://configuration.test") }
    var path: String { "/configuration/cache" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? { .default() }
}

private struct NtkAFConfigurationLegacyValidationRequest:
    iAFRequest,
    iNtkResponseValidation
{
    var baseURL: URL? { URL(string: "https://configuration.test") }
    var path: String { "/configuration/legacy-validation" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? { .default() }

    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        false
    }
}

private struct NtkAFConfigurationUploadRequest: iAFUploadRequest {
    var baseURL: URL? { URL(string: "https://configuration.test") }
    var path: String { "/configuration/upload" }
    var uploadSource: AFUploadSource { .data(Data()) }
}

private struct NtkAFConfigurationPassingValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private actor NtkAFConfigurationEventRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}

private struct NtkAFConfigurationRecordingHook: iNtkParsingHooks {
    let events: NtkAFConfigurationEventRecorder

    func didDecodeHeader(
        retCode: Int,
        msg: String?,
        context: NtkParsingContext
    ) async throws {
        await events.record("decoded")
    }

    func didComplete(
        _ response: any iNtkResponse,
        context: NtkParsingContext
    ) async throws {
        await events.record("completed")
    }
}

private struct NtkAFConfigurationDataToObjectTransformer: iNtkResponsePayloadTransforming {
    let events: NtkAFConfigurationEventRecorder

    func transform(
        _ payload: NtkPayload,
        context: NtkParsingContext
    ) async throws -> NtkPayload {
        await events.record("transform")
        guard case .data(let data) = payload else {
            return payload
        }
        return try NtkPayload.normalize(from: JSONSerialization.jsonObject(with: data))
    }
}

private struct NtkAFConfigurationCustomParser: iNtkResponseParser {
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        NtkResponse(
            code: NtkReturnCode(0),
            data: NtkAFConfigurationTestModel(id: 99),
            msg: "custom",
            response: true,
            request: context.request.originalRequest,
            isCache: false
        )
    }
}

private struct NtkAFConfigurationBoolCustomParser: iNtkResponseParser {
    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        NtkResponse(
            code: NtkReturnCode(0),
            data: true,
            msg: "custom",
            response: true,
            request: context.request.originalRequest,
            isCache: false
        )
    }
}

private struct NtkAFConfigurationCacheStorage: iNtkCacheStorage {
    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }

    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        nil
    }

    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }
}

private struct NtkAFConfigurationLegacyCacheStorage: iNtkCacheStorage {
    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }

    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        NtkCacheMeta(
            appVersion: "1.0",
            creationDate: Date().timeIntervalSince1970,
            expirationDate: Date().timeIntervalSince1970 + 60,
            data: Data(#"{"retCode":0,"data":{"id":1},"retMsg":"ok"}"#.utf8)
        )
    }

    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        true
    }
}

private final class NtkAFConfigurationURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeNtkAFConfigurationTestSession(body: Data) -> Session {
    NtkAFConfigurationURLProtocol.body = body
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [NtkAFConfigurationURLProtocol.self]
    return Session(configuration: configuration)
}
