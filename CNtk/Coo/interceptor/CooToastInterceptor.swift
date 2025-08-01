//
//  CooToastInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation
import Toast_Swift
import NtkNetwork

struct CooToastInterceptor: iNtkInterceptor {
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        
        guard let rpcRequest = context.client.requestWrapper.request as? iRpcRequest else {
            return try await next.handle(context: context)
        }
        do {
            let response = try await next.handle(context: context)
            return response
        } catch let error as NtkError {
            if case let .validation(_, response) = error {
                // 服务端验证失败，提示消息。
                if rpcRequest.toastRetErrorMsg, let msg = response.msg {
                    // toast提示
                    Task { @MainActor in
                        UIApplication.getKeyWindow()?.makeToast(msg)
                    }
                }
            } else if case .requestTimeout = error {
                Task { @MainActor in
                    UIApplication.getKeyWindow()?.makeToast("连接超时~")
                }
            } else if case .other(let error) = error {
                // 系统级别错误 mpaas框架提示
                let nsError = error as NSError
                if nsError.domain == kDTRpcException {
                    /// mPaaS错误类型
                    handleRpcError(nsError)
                }
                throw error
            }
            throw error
        } catch let rpcError as NtkError.Rpc {
            var msg: String?
            switch rpcError {
            case .responseEmpty:
                msg = "mPaaS接口响应数据为空"
            case .responseTypeError:
                msg = "接口数据类型异常"
            case .unknown(let message):
                msg = message
            }
            if let msg {
                // toast提示
                Task { @MainActor in
                    UIApplication.getKeyWindow()?.makeToast(msg)
                }
            }
            throw rpcError
        }
    }
    
    private func handleRpcError(_ error: NSError) {
        if let sysError = error.userInfo[kDTRpcErrorCauseError] as? URLError {
            /// mPaaS携带的抛向业务层的系统错误信息
            var msg: String = ""
            switch sysError.code {
            case .cancelled:
                print("mPaaS error")
                msg = "请求取消"
            case .badURL:
                print("mPaaS error")
                msg = "URL异常"
            case .networkConnectionLost:
                print("mPaaS error")
                msg = "异常错误"
            case .secureConnectionFailed:
                print("mPaaS error")
                msg = "异常错误"
            default:
                print("mPaaS error \(sysError.code)")
            }
            if !msg.isEmpty {
                Task { @MainActor in
                    UIApplication.getKeyWindow()?.makeToast(msg)
                }
            }
        }else {
            print("mPaaS error \(error)")
        }
    }
}


extension UIApplication {
    static func getKeyWindow() -> UIWindow? {
        var originalKeyWindow: UIWindow?
        if #available(iOS 13.0, *) {
            let connectedScenes = UIApplication.shared.connectedScenes
            for scene in connectedScenes {
                if scene.activationState == .foregroundActive, let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.isKeyWindow {
                            originalKeyWindow = window
                            break
                        }
                    }
                }
                if originalKeyWindow != nil {
                    break
                }
            }
        }else {
            originalKeyWindow = UIApplication.shared.keyWindow
        }
        return originalKeyWindow
    }
}
