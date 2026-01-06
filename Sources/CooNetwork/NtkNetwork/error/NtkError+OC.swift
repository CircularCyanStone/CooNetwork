//
//  NtkError+OC.swift
//  CooNetwork
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// 从错误模块导入NtkError
// 注意：确保NtkError.swift包含在同一个target中

// MARK: - 错误域常量
public let NtkErrorDomain = "NtkErrorDomain"
public let NtkCacheErrorDomain = "NtkCacheErrorDomain"

// MARK: - 错误码枚举
// 使用10000+范围避免与系统错误码冲突
@objc public enum NtkErrorCode: Int {
    case validation = 10001          // 验证失败
    case jsonInvalid = 10002         // JSON数据无效
    case decodeInvalid = 10003       // 解码失败
    case serviceDataEmpty = 10004    // 服务端数据为空
    case serviceDataTypeInvalid = 10005  // 服务端数据类型无效
    case typeMismatch = 10006        // 请求结果类型不匹配
    case requestCancelled = 10007    // 请求已被取消
    case requestTimeout = 10008      // 请求超时
    case other = 10020               // 其他错误
}

@objc public enum NtkCacheErrorCode: Int {
    case noCache = 20001             // 无缓存数据
}

// MARK: - NtkError Objective-C 桥接类
@objcMembers
public class NtkErrorBridge: NSObject {
    
    // MARK: - Objective-C 兼容的工厂方法
    
    /// 创建验证失败错误
    public static func validationError(request: Any, response: Any) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "验证失败",
            "request": request,
            "response": response
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.validation.rawValue, userInfo: userInfo)
    }
    
    /// 创建JSON数据无效错误
    public static func jsonInvalidError(request: Any, response: Any) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "JSON数据无效",
            "request": request,
            "response": response
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.jsonInvalid.rawValue, userInfo: userInfo)
    }
    
    /// 创建解码失败错误
    public static func decodeInvalidError(underlyingError: NSError, request: Any, response: Any) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "解码失败: \(underlyingError.localizedDescription)",
            "underlyingError": underlyingError,
            "request": request,
            "response": response
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.decodeInvalid.rawValue, userInfo: userInfo)
    }
    
    /// 创建服务端数据为空错误
    public static func serviceDataEmptyError() -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "服务端数据为空"
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.serviceDataEmpty.rawValue, userInfo: userInfo)
    }
    
    /// 创建服务端数据类型无效错误
    public static func serviceDataTypeInvalidError() -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "服务端数据类型无效"
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.serviceDataTypeInvalid.rawValue, userInfo: userInfo)
    }
    
    /// 创建请求结果类型不匹配错误
    public static func typeMismatchError() -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "请求结果类型不匹配"
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.typeMismatch.rawValue, userInfo: userInfo)
    }
    
    /// 创建请求已被取消错误
    public static func requestCancelledError() -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "请求已被取消"
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.requestCancelled.rawValue, userInfo: userInfo)
    }
    
    /// 创建请求超时错误
    public static func requestTimeoutError() -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "请求超时"
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.requestTimeout.rawValue, userInfo: userInfo)
    }
    
    /// 创建其他类型错误
    public static func otherError(underlyingError: NSError) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "其他错误: \(underlyingError.localizedDescription)",
            "underlyingError": underlyingError
        ]
        return NSError(domain: NtkErrorDomain, code: NtkErrorCode.other.rawValue, userInfo: userInfo)
    }
    
    /// 创建无缓存数据错误
    public static func noCacheError() -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "无缓存数据"
        ]
        return NSError(domain: NtkCacheErrorDomain, code: NtkCacheErrorCode.noCache.rawValue, userInfo: userInfo)
    }
    

    
    // MARK: - 错误类型检查便利方法
    
    /// 检查是否为验证失败错误
    public static func isValidationError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.validation.rawValue
    }
    
    /// 检查是否为JSON数据无效错误
    public static func isJSONInvalidError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.jsonInvalid.rawValue
    }
    
    /// 检查是否为解码失败错误
    public static func isDecodeInvalidError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.decodeInvalid.rawValue
    }
    
    /// 检查是否为服务端数据为空错误
    public static func isServiceDataEmptyError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.serviceDataEmpty.rawValue
    }
    
    /// 检查是否为服务端数据类型无效错误
    public static func isServiceDataTypeInvalidError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.serviceDataTypeInvalid.rawValue
    }
    
    /// 检查是否为请求结果类型不匹配错误
    public static func isTypeMismatchError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.typeMismatch.rawValue
    }
    
    /// 检查是否为请求已被取消错误
    public static func isRequestCancelledError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.requestCancelled.rawValue
    }
    
    /// 检查是否为请求超时错误
    public static func isRequestTimeoutError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.requestTimeout.rawValue
    }
    
    /// 检查是否为其他类型错误
    public static func isOtherError(_ error: NSError) -> Bool {
        return error.domain == NtkErrorDomain && error.code == NtkErrorCode.other.rawValue
    }
    
    /// 检查是否为缓存相关错误
    public static func isCacheError(_ error: NSError) -> Bool {
        return error.domain == NtkCacheErrorDomain
    }
}

// MARK: - 说明
// NtkError的Swift扩展应该直接添加到NtkError.swift文件中
// 以避免在桥接文件中出现模块可见性问题。
