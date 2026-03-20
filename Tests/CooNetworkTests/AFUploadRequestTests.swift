//
//  AFUploadRequestTests.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/03/20.
//

import Foundation
import Testing
import Alamofire

@testable import AlamofireClient
@testable import CooNetwork

struct AFUploadRequestTests {

    // MARK: - AFUploadSource

    @Test func testUploadSourceData() {
        let data = Data("hello".utf8)
        let source = AFUploadSource.data(data)
        if case .data(let d) = source {
            #expect(d == data)
        } else {
            Issue.record("Expected .data case")
        }
    }

    @Test func testUploadSourceFileURL() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let source = AFUploadSource.fileURL(url)
        if case .fileURL(let u) = source {
            #expect(u == url)
        } else {
            Issue.record("Expected .fileURL case")
        }
    }

    @Test func testUploadSourceMultipart() {
        let source = AFUploadSource.multipart { _ in }
        if case .multipart = source {
            #expect(Bool(true))
        } else {
            Issue.record("Expected .multipart case")
        }
    }

    // MARK: - iAFUploadRequest defaults

    @Test func testDefaultMethod() {
        let req = StubUploadRequest()
        #expect(req.method == .post)
    }

    @Test func testDefaultOnTransferProgressIsNil() {
        let req = StubUploadRequest()
        #expect(req.onTransferProgress == nil)
    }
}

/// 测试用最小上传请求
private struct StubUploadRequest: iAFUploadRequest {
    var baseURL: URL? { URL(string: "https://stub.test") }
    var path: String { "/upload" }
    var uploadSource: AFUploadSource { .data(Data("test".utf8)) }
}
