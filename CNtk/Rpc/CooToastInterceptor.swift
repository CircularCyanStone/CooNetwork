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
        guard let rpcRequest = context.client.request as? RpcRequest else {
            return try await next.handle(context: context)
        }
        do {
            let response = try await next.handle(context: context)
            return response
        } catch let error as NtkError {
            if case let .validation(_, response) = error {
                if rpcRequest.toastRetErrorMsg, let msg = response.msg {
                    // toast提示
                }
            }
            throw error
        } catch {
            // 系统级别错误 mpaas框架提示
            
            throw error
        }
    }
}
