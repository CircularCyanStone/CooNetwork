//
//  iNtkRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

@objcMembers
final class NtkHTTPMethod: NSObject, RawRepresentable, Sendable {
    /// `CONNECT` method.
    static let connect = NtkHTTPMethod(rawValue: "CONNECT")
    /// `DELETE` method.
    static let delete = NtkHTTPMethod(rawValue: "DELETE")
    /// `GET` method.
    static let get = NtkHTTPMethod(rawValue: "GET")
    /// `HEAD` method.
    static let head = NtkHTTPMethod(rawValue: "HEAD")
    /// `OPTIONS` method.
    static let options = NtkHTTPMethod(rawValue: "OPTIONS")
    /// `PATCH` method.
    static let patch = NtkHTTPMethod(rawValue: "PATCH")
    /// `POST` method.
    static let post = NtkHTTPMethod(rawValue: "POST")
    /// `PUT` method.
    static let put = NtkHTTPMethod(rawValue: "PUT")
    /// `QUERY` method.
    static let query = NtkHTTPMethod(rawValue: "QUERY")
    /// `TRACE` method.
    static let trace = NtkHTTPMethod(rawValue: "TRACE")

    let rawValue: String

    required init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@objc
protocol iNtkRequest {
    
    var baseURL: URL { get }
    
    var path: String { get }
    
    var method: NtkHTTPMethod { get }
    
    var headers: [String: String]? { get }
    
    /// 接口参数
    var parameters: [String: Any]? { get }
    
    var timeout: TimeInterval { get }
}
