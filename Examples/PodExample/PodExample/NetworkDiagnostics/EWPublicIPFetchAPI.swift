//
//  EWPublicIPFetchAPI.swift
//  ShangHangEWork
//
//  Created by MacBook Pro on 2026/2/27.
//  Copyright © 2026 Alibaba. All rights reserved.
//

import UIKit
import CooNetwork
import Alamofire

final class EWPublicIPFetchAPI: Sendable {

    @MainActor
    static func execute(_ ipType: IPType, _ completion: @escaping ((_ ip: String?, _ error: Error?) -> Void)) {
        Task {
            do {
                let result = try await NtkAF<ResponseModel>.withAF(
                    Request(ipType: ipType),
                    responseParser: NetworkInterceptor(),
                    validation: ResponseValidation()
                ).request()
                completion(result.data.ip, nil)
            } catch {
                completion(nil, error)

            }
        }
    }

    enum IPType {
        case V4, V6
    }

    private struct Request: iAFRequest {
        let ipType: IPType

        var baseURL: URL? {
            switch ipType {
            case .V4:
                return URL(string: "https://ipv4.tokyo.test-ipv6.com/ip/")
            case .V6:
                return URL(string: "https://ipv6.tokyo.test-ipv6.com/ip/")
            }
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

    private struct ResponseModel: Decodable, Sendable {
        let ip: String
        let type: String
    }

    private struct NetworkInterceptor: iNtkResponseParser {
        func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
            let response = try await next.handle(context: context)

            let rawData: Data
            if let clientResponse = response as? NtkClientResponse {
                if clientResponse.data is Data {
                    rawData = clientResponse.data as! Data
                } else if clientResponse.response is Data {
                    rawData = clientResponse.response as! Data
                } else {
                    throw NtkError.responseBodyEmpty(clientResponse: clientResponse)
                }
            } else {
                 throw NtkError.invalidResponseType(response: response)
            }

            guard var jsonString = String(data: rawData, encoding: .utf8) else {
                throw NtkError.Serialization.dataDecodingFailed(
                    context: .init(
                        clientResponse: nil,
                        recoveredResponse: nil,
                        rawPayload: nil,
                        underlyingError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid UTF8 Data"))
                    )
                )
            }

            let model: ResponseModel
            // 在转换成模型之前,先判断是否是JSONP格式，是则转换成JSON格式
            if let startIndex = jsonString.firstIndex(of: "("), let endIndex = jsonString.lastIndex(of: ")"), endIndex > startIndex, jsonString[startIndex...endIndex].count > 2 {
                jsonString = String(jsonString[jsonString.index(after: startIndex)..<endIndex])
                guard let jsonData = jsonString.data(using: .utf8) else {
                     throw NtkError.Serialization.dataDecodingFailed(
                        context: .init(
                            clientResponse: nil,
                            recoveredResponse: nil,
                            rawPayload: nil,
                            underlyingError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSON string"))
                        )
                    )
                }
                model = try JSONDecoder().decode(ResponseModel.self, from: jsonData)
            } else {
                model = try JSONDecoder().decode(ResponseModel.self, from: rawData)
            }

            return NtkResponse(
                code: NtkReturnCode(0),
                data: model,
                msg: "Success",
                response: response,
                request: context.mutableRequest.originalRequest,
                isCache: response.isCache
            )
        }
    }

    private struct ResponseValidation: iNtkResponseValidation {
        func isServiceSuccess(_ response: any CooNetwork.iNtkResponse) -> Bool {
            return true
        }
    }
}
