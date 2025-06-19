//
//  NtkValidationInterceptor.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

class NtkValidationInterceptor: iNtkInterceptor {
    func intercept(response: any iNtkResponse, context: NtkRequestContext) async throws -> any iNtkResponse {
        let serviceOK = context.validation.isServiceSuccess(response)
        if serviceOK {
            /// 服务端校验通过
            return response
            //            if let responseData = response.data {
//                let fixResponse = NtkResponse(code: response.code, data: responseData, msg: response.msg, response: response.response, request: response.request)
//                return fixResponse
//            }else if ResponseData.self is NtkNever.Type {
//                // 用户期待的数据类型就是Never，啥都没有
//                let fixResponse = NtkResponse(code: response.code, data: NtkNever() as! ResponseData, msg: response.msg, response: response.response, request: response.request)
//                return fixResponse
//            }else {
//                // 后端code验证成功，但是没有得到匹配的数据类型
//                throw NtkError.retDataError
//            }
        }else {
            throw NtkError.validation(response.request, response)
        }
    }
}
