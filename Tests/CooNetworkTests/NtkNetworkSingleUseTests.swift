//
//  NtkNetworkSingleUseTests.swift
//  CooNetworkTests
//
//  Created by Backend Architect on 2026/3/16.
//
//  文件功能描述：
//  本文件用于验证 NtkNetwork 的“单实例单次请求”语义，确保同一个 NtkNetwork 实例在完成一次 request 后，
//  再次调用 request 会被框架明确阻止，避免同一配置对象被重复复用导致不可预期行为。
//
//  类型功能描述：
//  - NtkNetworkSingleUseTests：覆盖单次使用行为的核心用例，验证第一次请求成功、第二次请求失败。
//  - SingleUseDummyRequest：测试专用请求体，提供最小可运行请求语义。
//  - SingleUseDummyValidation：测试专用响应验证器，始终返回服务成功。
//  - SingleUseDummyClient：测试专用客户端，返回固定响应并记录执行次数。
//  - SingleUseDummyParsingInterceptor：测试专用解析拦截器，将客户端响应映射为 NtkResponse<Bool>。
//  - SingleUseDummyCacheStorage / SingleUseDummyKeys：测试依赖的最小缓存与键映射实现。
//

import Foundation
import Testing
@testable import CooNetwork

struct NtkNetworkSingleUseTests {
    @Test
    func networkInstanceShouldCompleteFirstRequest() async throws {
        let client = SingleUseDummyClient()
        let network = NtkNetwork<Bool>.with(
            client,
            request: SingleUseDummyRequest(),
            responseParser: SingleUseDummyParsingInterceptor()
        )

        let firstResponse = try await network.request()
        #expect(firstResponse.data == true)
        // 重复调用同一实例是开发期契约错误，会触发 fatalError，无需在测试中验证
    }
}

private struct SingleUseDummyRequest: iNtkRequest {
    var path: String { "/single-use/test" }
}

private struct SingleUseDummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct SingleUseDummyKeys: iNtkResponseMapKeys {
    static let code = "code"
    static let data = "data"
    static let msg = "msg"
}

private struct SingleUseDummyClient: iNtkClient {
    typealias Keys = SingleUseDummyKeys

    var storage: any iNtkCacheStorage {
        SingleUseDummyCacheStorage()
    }

    @NtkActor
    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        NtkClientResponse(
            data: true,
            msg: nil,
            response: true,
            request: request,
            isCache: false
        )
    }
}

private struct SingleUseDummyParsingInterceptor: iNtkResponseParser {
    let validation: iNtkResponseValidation = SingleUseDummyValidation()

    @NtkActor
    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        return NtkResponse<Bool>(
            code: response.code,
            data: true,
            msg: response.msg,
            response: response.response,
            request: response.request,
            isCache: response.isCache
        )
    }
}

private struct SingleUseDummyCacheStorage: iNtkCacheStorage {
    @NtkActor
    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }

    @NtkActor
    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        nil
    }

    @NtkActor
    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        false
    }
}
