// Tests/CooNetworkTests/NtkTransferEventTests.swift
import Foundation
import Testing

@testable import CooNetwork

struct NtkTransferEventTests {

    @Test func testProgressCase() {
        let progress = NtkTransferProgress(
            completedUnitCount: 50,
            totalUnitCount: 100,
            fractionCompleted: 0.5
        )
        let event: NtkTransferEvent<String> = .progress(progress)

        if case .progress(let p) = event {
            #expect(p.fractionCompleted == 0.5)
        } else {
            Issue.record("Expected .progress case")
        }
    }

    @Test func testCompletedCase() {
        let response = NtkResponse<String>(
            code: .init(0),
            data: "ok",
            msg: nil,
            response: "raw",
            request: StubRequest(),
            isCache: false
        )
        let event: NtkTransferEvent<String> = .completed(response)

        if case .completed(let r) = event {
            #expect(r.data == "ok")
        } else {
            Issue.record("Expected .completed case")
        }
    }
}

/// 测试用桩请求
private struct StubRequest: iNtkRequest {
    var baseURL: URL? { URL(string: "https://stub.test") }
    var path: String { "/stub" }
    var method: NtkHTTPMethod { .get }
}
