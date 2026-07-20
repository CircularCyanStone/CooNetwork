//
//  EWDomainDiagnosticsAPI.swift
//  ShangHangEWork
//
//  Created by MacBook Pro on 2026/3/2.
//  Copyright © 2026 Alibaba. All rights reserved.
//

import UIKit
import CooNetwork
import Alamofire

final class EWDomainDiagnosticsAPI: Sendable {
    
    @MainActor
    static func execute(_ domain: String, _ completion: @escaping ((_ code: String, _ msg: String) -> Void)) {
        Task {
            do {
                let result = try await NtkAF<NtkNever>.withAF(
                    Request(domain: domain),
                    responseParser: NetworkInterceptor(),
                    validation: ResponseValidation()
                ).request()
                completion(result.code.stringValue, result.code.intValue == 200 ? "连接正常" : "连接异常")
            } catch let error as NtkError.Client {
                if case .external(_, let context) = error,
                   let afError = context.underlyingError as? AFError,
                   case .responseSerializationFailed(let reason) = afError,
                   case .inputDataNilOrZeroLength = reason {
                    if let clientResponse = context.clientResponse,
                       let ntkResponse = clientResponse.response as? NtkResponse<Data?>,
                       let statusCode = ntkResponse.code.int, statusCode > 0 {
                        completion(String(statusCode), statusCode == 200 ? "连接正常" : "连接异常")
                    } else {
                        completion("无", "连接异常")
                    }
                } else {
                    completion("无", "连接异常")
                }
            } catch {
                completion("无", "连接异常")
            }
        }
    }
    
    private struct Request: iAFRequest {
        let domain: String
        
        var baseURL: URL? {
            return URL(string: domain)
        }
        
        var path: String {
            return ""
        }
        
        var method: NtkHTTPMethod {
            return .get
        }
        
        var checkLogin: Bool {
            return false
        }
    }
    
    private struct NetworkInterceptor: iNtkResponseParser {
        func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
            let response = try await next.handle(context: context)
            
            guard let clientResponse = response as? NtkClientResponse, let afResponse = clientResponse.response as? DataResponse<Data, AFError>, let statusCode = afResponse.response?.statusCode else {
                throw NtkError.invalidResponseType(response: response)
            }
            
            return NtkResponse(
                code: NtkReturnCode(statusCode),
                data: NtkNever(),
                msg: statusCode == 200 ? "连接正常" : "连接异常",
                response: response,
                request: context.mutableRequest.originalRequest,
                isCache: response.isCache
            )
        }
    }
    
    private struct ResponseValidation: iNtkResponseValidation {
        func isServiceSuccess(_ response: any CooNetwork.iNtkResponse) -> Bool {
            if let code = response.code.int, code == 200 {
                return true
            }
            if response.code.stringValue == "200" {
                return true
            }
            return false
        }
    }
}
