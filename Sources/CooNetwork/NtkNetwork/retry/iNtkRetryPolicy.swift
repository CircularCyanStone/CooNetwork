//
//  iNtkRetryPolicy.swift
//  CNtk
//
//  重试策略协议定义
//

import Foundation

/// 重试策略协议
@NtkActor
public protocol iNtkRetryPolicy: Sendable {
    /// 最大重试次数
    var maxRetryCount: Int { get }
    
    /// 计算下次重试的延迟时间
    /// - Parameters:
    ///   - attemptCount: 当前重试次数（从1开始）
    ///   - error: 导致重试的错误
    /// - Returns: 延迟时间（秒），返回nil表示不应该重试
    func retryDelay(for attemptCount: Int, error: Error) -> TimeInterval?
    
    /// 判断是否应该重试
    /// - Parameters:
    ///   - attemptCount: 当前重试次数（从1开始）
    ///   - error: 导致重试的错误
    /// - Returns: 是否应该重试
    func shouldRetry(attemptCount: Int, error: Error) -> Bool
}

/// 重试策略的默认实现
extension iNtkRetryPolicy {
    public func shouldRetry(attemptCount: Int, error: Error) -> Bool {
        guard attemptCount <= maxRetryCount else { return false }
        
        // 检查是否是可重试的错误
        if let ntkError = error as? NtkError {
            switch ntkError {
            case .validation, .jsonInvalid, .decodeInvalid, .serviceDataEmpty, .serviceDataTypeInvalid,
                 .typeMismatch, .requestCancelled:
                return false
            case .requestTimeout:
                return true  // 超时错误应该重试
            case .other(let error):
                // 如果关联值是 URLError，使用 URLError 的重试逻辑
                if let urlError = error as? URLError {
                    return shouldRetryForURLError(urlError)
                }
                return false
            }
        }
        
        // 检查缓存错误
        if error is NtkError.Cache {
            return false
        }
        
        // 对于其他网络相关错误，默认可以重试
        if let urlError: URLError = error as? URLError {
            return shouldRetryForURLError(urlError)
        }
        
        return false
    }
    
    private func shouldRetryForURLError(_ urlError: URLError) -> Bool {
        switch urlError.code {
        // 网络相关错误，应该重试
        case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
            return true
        // 客户端错误，不应该重试
        case .badURL, .unsupportedURL, .cannotParseResponse, .badServerResponse, .userCancelledAuthentication, .userAuthenticationRequired:
            return false
        // 服务器错误，可以重试
        case .cannotLoadFromNetwork, .resourceUnavailable:
            return true
        // 其他未明确分类的错误，保守起见不重试
        default:
            return false
        }
    }
}
