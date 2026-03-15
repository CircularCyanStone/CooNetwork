//
//  ViewController.swift
//  PodExample
//
//  Created by 李奇奇 on 2026/1/7.
//

import UIKit
import CooNetwork
import Alamofire

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
    }


    @IBAction func requestAction(_ sender: Any) {
        // 执行 IPv6/IPv4 测试
        testIPv6()
    }
}

// MARK: - Response Model
struct IPv6Response: Decodable, Sendable {
    let ip: String
    let type: String
    let subtype: String?
    let via: String?
    let padding: String?
}

// MARK: - Request
struct IPv6Request: iAFRequest {
    let urlStr: String
    
    var baseURL: URL? {
        return URL(string: urlStr)
    }
    
    var path: String {
        return ""
    }
    
    var method: NtkHTTPMethod {
        return .get
    }
    
    var parameters: [String : any Sendable]? {
        // 使用固定的 callback 名字，方便解析
        return ["callback": "myCallback", "testdomain": "test-ipv6.com", "testname": "test_a"]
    }
    
    // 不需要登录态
    var checkLogin: Bool {
        return false
    }
}

// MARK: - Interceptor
struct IPv6ParsingInterceptor: iNtkInterceptor {
    
    func intercept(context: NtkInterceptorContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        
        // 1. 获取原始数据
        // 兼容两种携带位置：优先使用 response，其次使用 data
        let rawData: Data
        if let clientResponse = response as? NtkClientResponse {
            if let d = clientResponse.data as? Data {
                rawData = d
            } else if let d = clientResponse.response as? Data {
                rawData = d
            } else {
                throw NtkError.serviceDataEmpty
            }
        } else {
             throw NtkError.typeMismatch
        }
        
        guard let string = String(data: rawData, encoding: .utf8) else {
            throw NtkError.decodeInvalid(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid UTF8 Data")), rawData, context.mutableRequest.originalRequest)
        }
        
        // 2. 解析 JSONP: myCallback({...}) -> {...}
        // 简单提取第一个 { 和最后一个 } 之间的内容
        guard let firstBrace = string.firstIndex(of: "{"),
              let lastBrace = string.lastIndex(of: "}") else {
            throw NtkError.decodeInvalid(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSONP format")), rawData, context.mutableRequest.originalRequest)
        }
        
        let jsonString = String(string[firstBrace...lastBrace])
        guard let jsonData = jsonString.data(using: .utf8) else {
             throw NtkError.decodeInvalid(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSON string")), rawData, context.mutableRequest.originalRequest)
        }
        
        // 3. 解码 JSON
        let decoder = JSONDecoder()
        let model = try decoder.decode(IPv6Response.self, from: jsonData)
        
        // 4. 构建 NtkResponse
        // 注意：这里手动构建成功状态，因为该接口没有标准的 code/msg 字段
        // NtkReturnCode(0) 表示成功
        return NtkResponse(
            code: NtkReturnCode(0),
            data: model,
            msg: "Success",
            response: response, // 传递原始 response
            request: context.mutableRequest.originalRequest,
            isCache: response.isCache
        )
    }
}

// MARK: - Validation
struct IPv6Validation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        // 只要能解析出 NtkResponse，并且 code 为 0 (我们在 Interceptor 中设置的)，就认为是成功
        // 或者直接返回 true，因为 Interceptor 已经处理了业务逻辑
        return true
    }
}

// MARK: - Test Function
func testIPv6() {
    Task {
        print("\n🚀 Starting IPv4 Test...")
        let url1 = "https://ipv4.tokyo.test-ipv6.com/ip/"
        let req1 = IPv6Request(urlStr: url1)
        
        do {
            let result1 = try await NtkAF<IPv6Response>.withAF(
                req1,
                dataParsingInterceptor: IPv6ParsingInterceptor(),
                validation: IPv6Validation()
            ).request()
            print("✅ IPv4 Result: IP=\(result1.data.ip), Type=\(result1.data.type)")
        } catch {
            print("❌ IPv4 Failed: \(error)")
        }
        
        print("\n🚀 Starting IPv6 Test...")
        let url2 = "https://ipv6.tokyo.test-ipv6.com/ip/"
        let req2 = IPv6Request(urlStr: url2)
        
        do {
            let result2 = try await NtkAF<IPv6Response>.withAF(
                req2,
                dataParsingInterceptor: IPv6ParsingInterceptor(),
                validation: IPv6Validation()
            ).request()
            print("✅ IPv6 Result: IP=\(result2.data.ip), Type=\(result2.data.type)")
        } catch {
            print("❌ IPv6 Failed: \(error)")
        }
    }
}

