//
//  AFToastInterceptor.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
import CooNetwork

/// AF请求默认的Toast处理逻辑。
public struct AFToastInterceptor: iNtkInterceptor {
    
    /// Toast显示回调
    /// - Parameter msg: 需要显示的消息内容
    public typealias ToastHandler = @Sendable (String) -> Void
    
    /// Toast处理闭包
    private let toastHandler: ToastHandler
    
    /// 需要忽略的不做默认处理的code。
    public let ignoreCode: [Int]
    
    /// 初始化
    /// - Parameters:
    ///   - ignoreCode: 需要忽略的错误码
    ///   - toastHandler: Toast显示逻辑闭包
    public init(ignoreCode: [Int] = [], toastHandler: @escaping ToastHandler) {
        self.ignoreCode = ignoreCode
        self.toastHandler = toastHandler
    }
    
    public func intercept(context: NtkInterceptorContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        guard let afRequest = context.mutableRequest.originalRequest as? iAFRequest else {
            return try await next.handle(context: context)
        }
        do {
            let response = try await next.handle(context: context)
            return response
        } catch let error as NtkError {
            handleNtkError(error, request: afRequest)
            throw error
        } catch let afError as NtkError.AF {
            handleAFError(afError)
            throw afError
        } catch {
            // 处理其他未知的 Error
            throw error
        }
    }
    
    private func handleNtkError(_ error: NtkError, request: iAFRequest) {
        if case let .validation(_, response) = error {
            if ignoreCode.contains(response.code.intValue) {
                return
            }
            // 服务端验证失败，提示消息。
            if request.toastRetErrorMsg(response.code.stringValue), let msg = response.msg {
                // toast提示
                toastHandler(msg)
            }
        } else if case .requestTimeout = error {
            toastHandler("连接超时~")
        } else if case .other(let innerError) = error {
            // 系统级别错误
            let nsError = innerError as NSError
            handleSystemError(nsError)
        }
    }
    
    private func handleAFError(_ error: NtkError.AF) {
        var msg: String?
        switch error {
        case .responseEmpty:
            msg = "接口响应数据为空"
        case .responseTypeError:
            msg = "接口数据类型异常"
        case .unknown(let message):
            msg = message
        }
        if let msg = msg {
            toastHandler(msg)
        }
    }
    
    private func handleSystemError(_ error: NSError) {
        // 这里处理系统错误消息
        // 简单使用 localizedDescription
        // 可以在这里根据 error.code 做更细致的错误文案映射
        let msg = error.localizedDescription
        toastHandler(msg)
    }
}
