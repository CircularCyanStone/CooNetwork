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
    func jsonObjectDecoderDecodesScalarData() async throws {
        let stringValue: String? = try await decodeScalarData("plain text", as: String.self)
        let intValue: Int? = try await decodeScalarData(42, as: Int.self)
        let int64Value: Int64? = try await decodeScalarData(Int64(42), as: Int64.self)
        let floatValue: Float? = try await decodeScalarData(Float(1.25), as: Float.self)
        let doubleValue: Double? = try await decodeScalarData(12.5, as: Double.self)
        let boolValue: Bool? = try await decodeScalarData(true, as: Bool.self)
        let numberValue: Int? = try await decodeScalarData(NSNumber(value: 7), as: Int.self)
        let numberBoolValue: Bool? = try await decodeScalarData(NSNumber(value: true), as: Bool.self)

        #expect(stringValue == "plain text")
        #expect(intValue == 42)
        #expect(int64Value == 42)
        #expect(floatValue == 1.25)
        #expect(doubleValue == 12.5)
        #expect(boolValue == true)
        #expect(numberValue == 7)
        #expect(numberBoolValue == true)
    }

    @Test
    func jsonObjectDecoderDecodesObjectDataContainingNull() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": ["id": 1, "nickname": NSNull()]
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<AFNullableTestModel, AFTestKeys>()

        let result = try await decoder.decode(payload, context: makePayloadDecoderContext())

        #expect(result.data?.id == 1)
        #expect(result.data?.nickname == nil)
    }

    @Test
    func jsonObjectDecoderDecodesNestedDynamicDataValue() async throws {
        let payload = NtkPayload.dynamic(NtkDynamicData(dictionary: [
            "retCode": 0,
            "retMsg": "ok",
            "data": NtkDynamicData(dictionary: ["id": 1, "name": "nested"])
        ]))
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        let result = try await decoder.decode(payload, context: makePayloadDecoderContext())

        #expect(result.data?.id == 1)
        #expect(result.data?.name == "nested")
    }

    @Test
    func jsonObjectDecoderDecodesArrayData() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": [1, 2, 3]
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<[Int], AFTestKeys>()

        let result = try await decoder.decode(payload, context: makePayloadDecoderContext())

        #expect(result.data == [1, 2, 3])
    }

    @Test
    func jsonObjectDecoderTreatsNullDataAsNil() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": NSNull()
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        let result = try await decoder.decode(payload, context: makePayloadDecoderContext())

        #expect(result.data == nil)
    }

    @Test
    func jsonObjectDecoderExtractsScalarHeaderData() throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": 42
        ] as [String: Any])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        let header = try decoder.extractHeader(payload, request: AFConfiguredTestRequest())

        #expect(header?.data?.getInt() == 42)
    }

    @Test
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
    func jsonObjectDecoderRejectsNonDynamicPayload() async throws {
        let payload = try NtkPayload.normalize(from: Data("{\"retCode\":0,\"retMsg\":\"ok\"}".utf8))
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        do {
            _ = try await decoder.decode(payload, context: makePayloadDecoderContext())
            Issue.record("期望抛出 serialization.invalidEnvelope")
        } catch let error as NtkError.Serialization {
            if case .invalidEnvelope = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    func dataDecoderRejectsDynamicPayload() async throws {
        let payload = try NtkPayload.normalize(from: [
            "retCode": 0,
            "retMsg": "ok",
            "data": ["id": 1, "name": "test"]
        ] as [String: Any])
        let decoder = NtkDataPayloadDecoder<AFTestModel, AFTestKeys>()

        do {
            _ = try await decoder.decode(payload, context: makePayloadDecoderContext())
            Issue.record("期望抛出 serialization.invalidDataPayload")
        } catch let error as NtkError.Serialization {
            if case .invalidDataPayload = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }

    @Test
    func jsonObjectDecoderRejectsTopLevelArrayPayload() async throws {
        let payload = try NtkPayload.normalize(from: [
            ["id": 1, "name": "a"],
            ["id": 2, "name": "b"]
        ] as [[String: Any]])
        let decoder = NtkJSONObjectPayloadDecoder<AFTestModel, AFTestKeys>()

        do {
            _ = try await decoder.decode(payload, context: makePayloadDecoderContext())
            Issue.record("期望抛出 serialization.invalidEnvelope")
        } catch let error as NtkError.Serialization {
            if case .invalidEnvelope = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        }
    }
}

private func decodeScalarData<T: Decodable & Sendable>(
    _ raw: any Sendable,
    as type: T.Type
) async throws -> T? {
    let payload = try NtkPayload.normalize(from: [
        "retCode": 0,
        "retMsg": "ok",
        "data": raw
    ] as [String: any Sendable])
    let decoder = NtkJSONObjectPayloadDecoder<T, AFTestKeys>()
    return try await decoder.decode(payload, context: makePayloadDecoderContext()).data
}

private func makePayloadDecoderContext() -> NtkParsingContext {
    NtkParsingContext(request: NtkMutableRequest(AFConfiguredTestRequest()))
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

private struct AFNullableTestModel: Codable, Sendable {
    let id: Int
    let nickname: String?
}

private struct AFConfiguredTestRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/af/test/configured" }
    var method: NtkHTTPMethod { .get }
    var cacheConfiguration: NtkCacheConfiguration? { .default() }
}
