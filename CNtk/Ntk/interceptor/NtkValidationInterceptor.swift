//
//  NtkValidationInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

struct NtkValidationInterceptor: iNtkInterceptor {
    var priority: NtkInterceptorPriority {
        .priority(.high)
    }
    
    func intercept(context: NtkRequestContext, next: any NtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        let serviceOK = context.validation.isServiceSuccess(response)
        if serviceOK {
            /// 服务端校验通过
            return response
        }else {
            throw NtkError.validation(response.request, response)
        }
    }
}
