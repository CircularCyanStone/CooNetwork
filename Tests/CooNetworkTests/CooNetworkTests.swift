import Foundation
import Testing

@testable import AlamofireClient
@testable import CooNetwork

struct CooNetworkTests {

    // MARK: - Models

    /// 模拟的用户信息模型
    struct UserInfo: Codable, Sendable {
        let id: Int
        let name: String
        let email: String
    }

    // MARK: - Requests

    /// 示例 1: GET 请求获取用户信息
    struct GetUserInfoRequest: iAFRequest {
        let userId: Int

        // 填入你的真实域名
        var baseURL: URL? { URL(string: "https://api.example.com") }

        var path: String { "/user/info" }

        var method: NtkHTTPMethod { .get }

        var parameters: [String: any Sendable]? {
            ["id": userId]
        }

        // 可选：自定义超时时间
        var timeout: TimeInterval { 10 }
    }

    /// 示例 2: POST 请求更新数据
    struct UpdateProfileRequest: iAFRequest {
        let newName: String

        var baseURL: URL? { URL(string: "https://api.example.com") }

        var path: String { "/user/profile/update" }

        var method: NtkHTTPMethod { .post }

        var parameters: [String: any Sendable]? {
            ["name": newName]
        }
    }

    /// 示例 3: 不需要返回数据的请求 (Ping / Report)
    struct ReportRequest: iAFRequest {
        var baseURL: URL? { URL(string: "https://api.example.com") }
        var path: String { "/stat/report" }
        var method: NtkHTTPMethod { .post }
    }

    // MARK: - Tests

    @Test func testGetUserInfo() async throws {
        let request = GetUserInfoRequest(userId: 1001)
        let network = NtkAF<UserInfo>.withAF(request)
        await expectExampleRequestFailure {
            _ = try await network.request()
        }
    }

    @Test func testUpdateProfile() async throws {
        let request = UpdateProfileRequest(newName: "CooNetwork User")
        let network = NtkAFBool.withAF(request)
        await expectExampleRequestFailure {
            _ = try await network.request()
        }
    }

    @Test func testReportWithNoData() async throws {
        let request = ReportRequest()
        let network = NtkAF<NtkNever>.withAF(request)
        await expectExampleRequestFailure {
            _ = try await network.request()
        }
    }

    @Test func testWithCustomCache() async throws {
        let request = GetUserInfoRequest(userId: 1002)

        // 模拟一个缓存存储
        struct MemoryCache: iNtkCacheStorage {
            func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async
                -> Bool
            {
                print("Cache Set: \(key)")
                return true
            }
            func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
                return nil
            }
            func hasData(key: String, for request: NtkMutableRequest) async -> Bool { return false }
        }

        let network = NtkAF<UserInfo>.withAF(
            request,
            storage: MemoryCache()
        )

        await expectExampleRequestFailure {
            _ = try await network.request()
        }
    }
}

extension CooNetworkTests {
    fileprivate func expectExampleRequestFailure(_ execution: () async throws -> Void) async {
        do {
            try await execution()
            Issue.record("示例域名请求应失败，但实际成功")
        } catch let error as NtkError {
            switch error {
            case NtkError.requestTimeout:
                #expect(Bool(true))
            case NtkError.requestCancelled:
                #expect(Bool(true))
            default:
                Issue.record("捕获到非预期 NtkError: \(error)")
            }
        } catch let _ as NtkError.Client {
            #expect(Bool(true))
        } catch {
            Issue.record("捕获到非预期错误类型: \(error)")
        }
    }
}
