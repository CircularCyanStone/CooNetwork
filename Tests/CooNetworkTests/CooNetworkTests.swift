import Testing
import Foundation
@testable import CooNetwork
@testable import CooNetworkAFClient

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
        
        var parameters: [String : any Sendable]? {
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
        
        var parameters: [String : any Sendable]? {
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
        
        do {
            // 使用 NtkAF<T> 别名，T 为期望的 Response Model
            // 注意：withAF 是 async 的，需要 await
            let network = await NtkAF<UserInfo>.withAF(request)
            
            // 发起请求
            let response = try await network.request()
            
            // 验证结果
            #expect(response.code.intValue == 0) // 假设 0 为成功码
            #expect(response.data.id == 1001)
            print("User Info: \(response.data)")
            
        } catch {
            // 这里的 Error 可能是网络错误、解析错误或业务校验错误
            print("GetUserInfo Request Failed: \(error)")
            // 注意：如果没有真实的后端服务，这里报错是预期的
        }
    }

    @Test func testUpdateProfile() async throws {
        let request = UpdateProfileRequest(newName: "CooNetwork User")
        
        do {
            // 如果接口只返回成功/失败，没有具体 data 结构，可以使用 NtkAFBool
            // NtkAFBool 是 Ntk<Bool, AFResponseMapKeys> 的别名
            let network = await NtkAFBool.withAF(request)
            
            let response = try await network.request()
            
            #expect(response.data == true)
            print("Update Success")
            
        } catch {
            print("UpdateProfile Request Failed: \(error)")
        }
    }
    
    @Test func testReportWithNoData() async throws {
        let request = ReportRequest()
        
        do {
            // 如果不需要关心 data，使用 NtkNever
            let network = await NtkAF<NtkNever>.withAF(request)
            
            let response = try await network.request()
            
            #expect(response.code.intValue == 0)
            print("Report Success")
            
        } catch {
            print("Report Request Failed: \(error)")
        }
    }
    
    @Test func testWithCustomCache() async throws {
        let request = GetUserInfoRequest(userId: 1002)
        
        // 模拟一个缓存存储
        struct MemoryCache: iNtkCacheStorage {
            func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
                print("Cache Set: \(key)")
                return true
            }
            func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? { return nil }
            func hasData(key: String, for request: NtkMutableRequest) async -> Bool { return false }
        }
        
        do {
            // 传入自定义的缓存策略
            let network = await NtkAF<UserInfo>.withAF(
                request,
                cacheStorage: MemoryCache()
            )
            
            _ = try await network.request()
            
        } catch {
            print("Cache Test Request Failed: \(error)")
        }
    }
}
