import Testing
import Foundation
@testable import CooNetwork

struct NtkPayloadTransformerTests {

    @Test
    @NtkActor
    func transformersRunInOrder() async throws {
        let payload = try NtkPayload.normalize(from: Data("seed".utf8))
        let context = makeTransformerContext()
        let transformerA = RecordingTransformer(name: "A")
        let transformerB = RecordingTransformer(name: "B")

        let first = try await transformerA.transform(payload, context: context)
        _ = try await transformerB.transform(first, context: context)

        #expect(transformerA.events == ["A"])
        #expect(transformerB.events == ["B"])
    }

    @Test
    @NtkActor
    func transformerCanConvertDataToDynamic() async throws {
        let payload = try NtkPayload.normalize(from: Data("seed".utf8))
        let context = makeTransformerContext()
        let transformer = DataToDynamicTransformer()

        let transformed = try await transformer.transform(payload, context: context)
        guard case .dynamic(let dynamic) = transformed else {
            Issue.record("期望 dynamic payload")
            return
        }

        #expect(dynamic["value"]?.getString() == "decoded")
    }

    @Test
    @NtkActor
    func dynamicToDataOnlyAllowedForExplicitReserializeNeed() async throws {
        let payload = try NtkPayload.normalize(from: ["value": "decoded"] as [String: any Sendable])
        let context = makeTransformerContext()
        let transformer = DynamicToDataTransformer()

        let transformed = try await transformer.transform(payload, context: context)
        guard case .data(let data) = transformed else {
            Issue.record("期望 data payload")
            return
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(json?["value"] == "decoded")
    }

    @Test
    @NtkActor
    func transformErrorStopsPipelineBeforeDecode() async throws {
        let payload = try NtkPayload.normalize(from: Data("seed".utf8))
        let context = makeTransformerContext()
        let transformer = FailingTransformer()

        await #expect(throws: NtkError.self) {
            _ = try await transformer.transform(payload, context: context)
        }
    }
}

@NtkActor
private func makeTransformerContext() -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(TransformerTestRequest()),
        client: TransformerTestClient()
    )
}

private struct TransformerTestRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/transformer/test" }
    var method: NtkHTTPMethod { .get }
}

private struct TransformerTestClient: iNtkClient {
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: Data(), msg: nil, response: Data(), request: request, isCache: false)
    }
}

private final class RecordingTransformer: iNtkResponsePayloadTransforming, @unchecked Sendable {
    let name: String
    var events: [String] = []

    init(name: String) {
        self.name = name
    }

    func transform(_ payload: NtkPayload, context: NtkInterceptorContext) async throws -> NtkPayload {
        events.append(name)
        return payload
    }
}

private struct DataToDynamicTransformer: iNtkResponsePayloadTransforming {
    func transform(_ payload: NtkPayload, context: NtkInterceptorContext) async throws -> NtkPayload {
        guard case .data = payload else { throw NtkError.typeMismatch }
        return try NtkPayload.normalize(from: ["value": "decoded"] as [String: any Sendable])
    }
}

private struct DynamicToDataTransformer: iNtkResponsePayloadTransforming {
    func transform(_ payload: NtkPayload, context: NtkInterceptorContext) async throws -> NtkPayload {
        guard case .dynamic(let dynamic) = payload,
              let dict = dynamic.getDictionary()
        else { throw NtkError.typeMismatch }

        let data = try JSONSerialization.data(withJSONObject: dict)
        return .data(data)
    }
}

private struct FailingTransformer: iNtkResponsePayloadTransforming {
    func transform(_ payload: NtkPayload, context: NtkInterceptorContext) async throws -> NtkPayload {
        throw NtkError.typeMismatch
    }
}
