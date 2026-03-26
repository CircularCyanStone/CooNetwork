import Foundation
import Testing
@testable import CooNetwork

struct NtkErrorBridgeTests {
    @Test
    func bridgeRequestErrorUsesRequestCodeRange() {
        let error = NtkError.request(.init(reason: .typeMismatch))
        let nsError = NtkErrorBridge.bridge(error)

        #expect(nsError.domain == NtkErrorDomain)
        #expect(nsError.code == NtkErrorCode.requestTypeMismatch.rawValue)
        #expect(NtkErrorBridge.isRequestError(nsError))
    }

    @Test
    func bridgeResponseErrorIncludesRequestAndClientResponse() {
        let request = BridgeRequest()
        let clientResponse = NtkClientResponse(data: Data("{}".utf8), msg: nil, response: Data(), request: request, isCache: false)
        let error = NtkError.response(.init(reason: .timedOut, context: .init(request: request, clientResponse: clientResponse, underlyingError: URLError(.timedOut))))
        let nsError = NtkErrorBridge.bridge(error)

        #expect(nsError.code == NtkErrorCode.responseTimedOut.rawValue)
        #expect(nsError.userInfo["request"] != nil)
        #expect(nsError.userInfo["clientResponse"] != nil)
        #expect(nsError.userInfo["underlyingError"] != nil)
    }

    @Test
    func bridgeSerializationErrorIncludesRecoveredResponseAndRawPayload() {
        let request = BridgeRequest()
        let clientResponse = NtkClientResponse(data: Data("{}".utf8), msg: nil, response: Data(), request: request, isCache: false)
        let recovered = NtkResponse<NtkDynamicData?>(code: .init(1), data: NtkDynamicData(dictionary: ["reason": "mock"]), msg: "bad", response: clientResponse, request: request, isCache: false)
        let error = NtkError.serialization(.init(reason: .dataDecodeFailed, context: .init(request: request, clientResponse: clientResponse, recoveredResponse: recovered, rawPayload: Data("{}".utf8), underlyingError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x")), stage: .model)))
        let nsError = NtkErrorBridge.bridge(error)

        #expect(nsError.code == NtkErrorCode.serializationDataDecodeFailed.rawValue)
        #expect(nsError.userInfo["request"] != nil)
        #expect(nsError.userInfo["clientResponse"] != nil)
        #expect(nsError.userInfo["recoveredResponse"] != nil)
        #expect(nsError.userInfo["underlyingError"] != nil)
        #expect(nsError.userInfo["rawPayload"] != nil)
    }

    @Test
    func bridgeValidationErrorIncludesResponse() {
        let request = BridgeRequest()
        let response = NtkResponse<Bool>(code: .init(999), data: false, msg: "fail", response: false, request: request, isCache: false)
        let error = NtkError.validation(.init(reason: .serviceRejected, context: .init(request: request, response: response)))
        let nsError = NtkErrorBridge.bridge(error)

        #expect(nsError.code == NtkErrorCode.validationServiceRejected.rawValue)
        #expect(nsError.userInfo["request"] != nil)
        #expect(nsError.userInfo["response"] != nil)
    }

    @Test
    func bridgeClientErrorUsesClientRange() {
        let error = NtkError.client(.af(.init(reason: .unknown, context: .init(message: "unknown"))))
        let nsError = NtkErrorBridge.bridge(error)

        #expect(nsError.code == NtkErrorCode.clientAFUnknown.rawValue)
        #expect(NtkErrorBridge.isClientError(nsError))
    }
}

private struct BridgeRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/bridge/test" }
    var method: NtkHTTPMethod { .get }
}
