//
//  NtkError.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import Foundation

import Foundation

// 定义一个基础的应用错误协议
protocol iNtkError: Error, CustomNSError, LocalizedError {
    
    // 用户可见的错误标题 (可选)
    var errorTitle: String? { get }
}


extension iNtkError {
    static var errorDomain: String {
        // 默认的错误域，可以根据需要更改
        return "com.yourapp.AppError"
    }

    var errorUserInfo: [String : Any] {
        var userInfo: [String: Any] = [:]

        // 将协议属性映射到 NSError.userInfo keys
        if let title = errorTitle {
            userInfo[NSLocalizedDescriptionKey] = title // 使用标题作为主要描述
        } else if let description = errorDescription {
            userInfo[NSLocalizedDescriptionKey] = description
        }

        if let description = errorDescription {
            userInfo[NSLocalizedFailureReasonErrorKey] = description // 失败原因
        }
        
        // 可以在这里添加更多通用的 userInfo
        userInfo["AppErrorCode"] = errorCode // 自定义 key
        userInfo["ErrorType"] = String(describing: type(of: self)) // 记录错误类型
        
        return userInfo
    }
}

enum NtkError: Int, iNtkError {
    case invalidURL = 1001
    case noConnection = 1002
    case serverError = 1003
    case timeout = 1004

    // MARK: - AppError 协议实现
    
    // 覆盖默认的 errorDomain，为网络错误提供更具体的域
    static var errorDomain: String {
        return "com.coo.ntk"
    }

    var errorCode: Int {
        return self.rawValue // 使用枚举的原始值作为错误码
    }

    var errorTitle: String? {
        switch self {
        case .invalidURL: return "无效的地址"
        case .noConnection: return "无网络连接"
        case .serverError: return "服务器错误"
        case .timeout: return "请求超时"
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请求的URL格式不正确，请检查。"
        case .noConnection: return "请检查您的网络连接并重试。"
        case .serverError: return "服务器当前无法响应，请稍后再试。"
        case .timeout: return "网络请求耗时过长，请检查网络后重试。"
        }
    }
}
