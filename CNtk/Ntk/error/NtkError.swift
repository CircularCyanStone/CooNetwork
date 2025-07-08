//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

enum NtkError: Error {
    case validation(_ request: iNtkRequest, _ response: Any)
    case jsonInvalid(_ request: iNtkRequest, _ response: Any)
    case decodeInvalid(_ error: Error, _ request: iNtkRequest, _ response: Any)
    case responseDataEmpty
    case responseDataTypeError
    case other(_ error: Error)
    
    // 缓存一类的错误
    enum Cache: Error {
    case noCache
    }
}




@objc
enum NtkErrorCode: Int {
    case invalidURL = 1001
    case noConnection = 1002
    case serverError = 1003
    case timeout = 1004
}

@objcMembers
class NtkOCError: NSObject {
    
    static var errorDomain: String {
        return "com.coo.ntk"
    }

    let errorCode: Int

    private var _errorDescription: String?
    
    var errorDescription: String? {
        if let errorCode = NtkErrorCode(rawValue: errorCode) {
            switch errorCode {
            case .invalidURL: return "请求的URL格式不正确，请检查。"
            case .noConnection: return "请检查您的网络连接并重试。"
            case .serverError: return "服务器当前无法响应，请稍后再试。"
            case .timeout: return "网络请求耗时过长，请检查网络后重试。"
            }
        }
        return _errorDescription
    }
    
    init(_ errorCode: Int, _ errorDescription: String?) {
        self.errorCode = errorCode
        _errorDescription = errorDescription
    }
    
    init(ntkErrorCode: NtkErrorCode) {
        self.errorCode = ntkErrorCode.rawValue
    }
}
