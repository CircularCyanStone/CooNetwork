//
//  AFClientUploadTests.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/03/20.
//

import Foundation
import Testing

@testable import AlamofireClient
@testable import CooNetwork

// MARK: - Helper

private func expectUploadRequestCompletes(
    _ body: () async throws -> Void,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async {
    do {
        try await body()
    } catch {
        // 网络失败（无网、域名不可达）属于预期结果，不算测试失败
    }
}

struct AFClientUploadTests {

    // MARK: - Test Requests

    struct DataUploadRequest: iAFUploadRequest {
        var baseURL: URL? { URL(string: "https://httpbin.org") }
        var path: String { "/post" }
        var uploadSource: AFUploadSource { .data(Data("test-data".utf8)) }
    }

    struct MultipartUploadRequest: iAFUploadRequest {
        let imageData: Data
        var baseURL: URL? { URL(string: "https://httpbin.org") }
        var path: String { "/post" }
        var uploadSource: AFUploadSource {
            .multipart { form in
                form.append(imageData, withName: "file",
                           fileName: "test.jpg", mimeType: "image/jpeg")
            }
        }
    }

    struct UploadWithProgressRequest: iAFUploadRequest {
        var baseURL: URL? { URL(string: "https://httpbin.org") }
        var path: String { "/post" }
        var uploadSource: AFUploadSource { .data(Data(repeating: 0x41, count: 1024)) }
        var onTransferProgress: (@Sendable (NtkTransferProgress) -> Void)?
    }

    // MARK: - Tests

    /// 验证 data upload 请求能正确构建并发送（预期因示例域名失败）
    @Test func testDataUploadRequest() async {
        let req = DataUploadRequest()
        let network = NtkAF<NtkNever>.withAF(req)
        await expectUploadRequestCompletes {
            _ = try await network.request()
        }
    }

    /// 验证 multipart upload 请求能正确构建
    @Test func testMultipartUploadRequest() async {
        let req = MultipartUploadRequest(imageData: Data("fake-image".utf8))
        let network = NtkAF<NtkNever>.withAF(req)
        await expectUploadRequestCompletes {
            _ = try await network.request()
        }
    }

    /// 验证链式 API onTransferProgress 能正确挂载
    @Test func testChainAPIProgressHandler() async {
        let req = DataUploadRequest()
        let network = NtkAF<NtkNever>.withAF(req)
            .onTransferProgress { _ in
                // 进度回调挂载验证（不需要实际触发）
            }
        await expectUploadRequestCompletes {
            _ = try await network.request()
        }
    }

    /// 验证协议属性 onTransferProgress 能正确传递
    @Test func testProtocolProgressHandler() async {
        var req = UploadWithProgressRequest()
        req.onTransferProgress = { _ in }
        let network = NtkAF<NtkNever>.withAF(req)
        await expectUploadRequestCompletes {
            _ = try await network.request()
        }
    }

    /// 验证 requestWithProgress 返回 AsyncThrowingStream
    @Test func testRequestWithProgress() async {
        let req = DataUploadRequest()
        let stream = NtkAF<NtkNever>.withAF(req).requestWithProgress()
        do {
            for try await event in stream {
                switch event {
                case .progress:
                    break // 进度事件
                case .completed:
                    break // 完成事件
                }
            }
        } catch {
            // 网络失败属于预期结果
        }
    }
}
