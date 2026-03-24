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
