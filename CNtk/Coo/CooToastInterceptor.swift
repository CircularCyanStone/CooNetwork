//
//  CooToastInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/9.
//

import Foundation
import Toast_Swift


struct CooToastInterceptor: iNtkInterceptor {
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        
        
        guard let rpcRequest = context.client.requestWrapper.request as? RpcRequest else {
            return try await next.handle(context: context)
        }
        do {
            let response = try await next.handle(context: context)
            return response
        } catch let error as NtkError {
            if case let .validation(_, response) = error {
                if rpcRequest.toastRetErrorMsg, let msg = response.msg {
                    // toast提示
                    Task { @MainActor in
                        UIApplication.getKeyWindow()?.makeToast(msg)
                    }
                }
            }
            throw error
        } catch {
            // 系统级别错误 mpaas框架提示
            
            throw error
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
