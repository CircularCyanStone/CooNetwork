import Foundation
import Testing
import Alamofire

@testable import AlamofireClient
@testable import CooNetwork

struct AFErrorMappingTests {
    @Test
    func afErrorHelperStillMapsCancelToAFClientError() {
        let mapped = NtkClientError.fromAFError(
            AFError.explicitlyCancelled,
            request: AFMappingRequest(),
            clientResponse: nil
        )

        if case let .external(reason, request, clientResponse, underlyingError, message) = mapped {
            #expect(request?.path == "/af/mapping")
            #expect(clientResponse == nil)
            #expect(underlyingError != nil)
            #expect(message != nil)
            #expect(reason is NtkClientError.AF)
        } else {
            Issue.record("错误类型不符: \(mapped)")
        }
    }

    @Test
    func afErrorHelperStillCapturesTimedOutUnderlyingError() {
        let afError = AFError.sessionTaskFailed(error: URLError(.timedOut))
        let mapped = NtkClientError.fromAFError(
            afError,
            request: AFMappingRequest(),
            clientResponse: nil
        )

        if case let .external(reason, request, clientResponse, underlyingError, message) = mapped {
            #expect(request?.path == "/af/mapping")
            #expect(clientResponse == nil)
            let capturedAFError = underlyingError as? AFError
            #expect(capturedAFError != nil)
            #expect(message != nil)
            #expect(reason is NtkClientError.AF)
        } else {
            Issue.record("错误类型不符: \(mapped)")
        }
    }
}

private struct AFMappingRequest: iAFRequest {
    var baseURL: URL? { URL(string: "https://test.example.com") }
    var path: String { "/af/mapping" }
    var method: NtkHTTPMethod { .get }
}
