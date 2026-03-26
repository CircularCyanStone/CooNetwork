import Testing
import Foundation
@testable import CooNetwork
@testable import AlamofireClient

struct NtkPayloadDecoderTests {

    @Test
    func dataDecoderExtractsHeaderFromFinalPayload() throws {
        let payload = try NtkPayload.normalize(from: Data("{\"retCode\":999,\"retMsg\":\"fail\",\"data\":{\"reason\":\"mock\"}}".utf8))
        let decoder = NtkDataPayloadDecoder<AFTestModel, AFTestKeys>()
        let header = try decoder.extractHeader(payload, request: AFConfiguredTestRequest())

        #expect(header?.code.intValue == 999)
        #expect(header?.msg == "fail")
        #expect(header?.data?["reason"]?.getString() == "mock")
    }

    @Test
    @NtkActor
    func jsonObjectDecoderDecodesModelFromDynamicObjectPayload() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": ["id": 1, "name": "test"]
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        let result = try await decoder.decode(payload, context: makePayloadDecoderContext())

        #expect(result.code.intValue == 0)
        #expect(result.msg == "ok")
        #expect(result.data?.id == 1)
        #expect(result.data?.name == "test")
    }

    @Test
    @NtkActor
    func jsonObjectDecoderReturnsNilDataWhenDataFieldMissing() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok"
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        let result = try await decoder.decode(payload, context: makePayloadDecoderContext())

        #expect(result.code.intValue == 0)
        #expect(result.msg == "ok")
        #expect(result.data == nil)
    }

    @Test
    func jsonObjectDecoderExtractsHeaderFromDynamicObjectPayload() throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 999,
            "retMsg": "fail",
            "data": ["reason": "mock"]
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        let header = try decoder.extractHeader(payload, request: AFConfiguredTestRequest())

        #expect(header?.code.intValue == 999)
        #expect(header?.msg == "fail")
        #expect(header?.data?["reason"]?.getString() == "mock")
    }

    @Test
    @NtkActor
    func jsonObjectDecoderRejectsNonDynamicPayload() async throws {
        let payload = try NtkPayload.normalize(from: Data("{\"retCode\":0,\"retMsg\":\"ok\"}".utf8))
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        do {
            _ = try await decoder.decode(payload, context: makePayloadDecoderContext())
            Issue.record("期望抛出 serialization.envelopeDecodeFailed")
        } catch let error as NtkError {
            if case let NtkError.responseSerializationFailed(reason: reason) = error,
               case .invalidEnvelope = reason {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func dataDecoderRejectsDynamicPayload() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": ["id": 1, "name": "test"]
        ] as [String: Any])
        let decoder = NtkDataPayloadDecoder<AFTestModel, AFTestKeys>()

        do {
            _ = try await decoder.decode(payload, context: makePayloadDecoderContext())
            Issue.record("期望抛出 serialization.dataDecodeFailed")
        } catch let error as NtkError {
            if case let .responseSerializationFailed(reason: reason) = error,
               case .invalidDataPayload = reason {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    @NtkActor
    func jsonObjectDecoderRejectsTopLevelArrayPayload() async throws {
        let payload = try NtkPayload.normalize(from: [
            ["id": 1, "name": "a"],
            ["id": 2, "name": "b"]
        ] as [[String: Any]])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        do {
            _ = try await decoder.decode(payload, context: makePayloadDecoderContext())
            Issue.record("期望抛出 serialization.envelopeDecodeFailed")
        } catch let error as NtkError {
            if case let NtkError.responseSerializationFailed(reason: reason) = error,
               case .invalidEnvelope = reason {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }
}

@NtkActor
private func makePayloadDecoderContext() -> NtkInterceptorContext {
    NtkInterceptorContext(
        mutableRequest: NtkMutableRequest(AFConfiguredTestRequest()),
        client: AFPayloadDecoderDummyClient()
    )
}

private struct AFTestKeys: iNtkResponseMapKeys {
    static let code = "retCode"
    static let data = "data"
    static let msg = "retMsg"
}

private struct AFTestModel: Codable, Sendable {
    let id: Int
    let name: String
}

private struct AFConfiguredTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/af/test/configured" }
    var method: NtkHTTPMethod { .get }
    var requestConfiguration: NtkRequestConfiguration? { .default() }
}

private struct AFPayloadDecoderDummyClient: iNtkClient {
    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
    }
}
