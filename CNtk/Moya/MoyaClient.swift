//
//  MoyaClient.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit
import Moya

class MoyaClient<R: TargetType, Keys: NtkResponseMapKeys>: NSObject, iNtkClient {
    
    private(set) var request: iNtkRequest?
    
    private(set) var moyaRequest: R?
    
    private(set) var isFinished: Bool = false
    
    var isCancelled: Bool {
        if let cancelToken {
            return cancelToken.isCancelled
        }
        return false
    }
    
    private let provider: MoyaProvider<R>
    
    private var cancelToken: (any Cancellable)?
    
    init(
        endpointClosure: @escaping MoyaProvider<R>.EndpointClosure = MoyaProvider<R>.defaultEndpointMapping,
        requestClosure: @escaping MoyaProvider<R>.RequestClosure = MoyaProvider<R>.defaultRequestMapping,
        stubClosure: @escaping MoyaProvider<R>.StubClosure = MoyaProvider<R>.neverStub,
         session: Session = MoyaProvider<R>.defaultAlamofireSession(),
         plugins: [PluginType] = [],
         trackInflights: Bool = false) {
        
        self.provider = MoyaProvider<R>(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, session: session, plugins: plugins, trackInflights: trackInflights)
    }
    
    func addRequest(_ req: any iNtkRequest) {
        request = req
        if let moyaRequest = req as? R {
            self.moyaRequest = moyaRequest
        }
    }
    
    func cancel() {
        cancelToken?.cancel()
        cancelToken = nil
    }
    
//    func execute<ResponseData>(_ completion: @escaping (NtkResponse<ResponseData>) -> Void, failure: (NtkError) -> Void) where ResponseData : Decodable, ResponseData : Encodable {
//        guard let moyaRequest else {
//            return
//        }
//        cancelToken = provider.request(moyaRequest) { result in
//            switch result {
//            case .success(let response):
//                do {
//                    let okResponse = try response.filter(statusCode: 200)
//                    let responseModel = try okResponse.map(NtkResponseModel<ResponseData, Keys>.self)
//                    let ntkResponse = NtkResponse(code: responseModel.code, data: responseModel.data, msg: responseModel.msg, response: okResponse, request: self.request!)
//                    completion(ntkResponse)
//                } catch {
////                    failure(error)
//                }
//            case .failure(let moyaError):
////                failure(error)
//                print("===")
//            }
//        }
//    }
    
    
    /// ResponseData是Decodable模式时，执行请求的方案
    /// - Returns: 响应结果
    func execute<ResponseData>() async throws -> NtkResponse<ResponseData> where ResponseData : Decodable {
        assert(moyaRequest != nil, "request is nil or not implement TargetType protocol")
        do {
            let response = try await withCheckedThrowingContinuation { continuatuon in
                self.cancelToken = provider.request(moyaRequest!) { result in
                    switch result {
                    case .success(let response):
                        do {
                            let okResponse = try response.filter(statusCode: 200)
                            let responseData = try okResponse.map(NtkResponseDecoder<ResponseData, Keys>.self)
                            if let returnData = responseData.data {
                                let fixResponse = NtkResponse(code: responseData.code, data: returnData, msg: responseData.msg, response: okResponse, request: self.request!)
                                continuatuon.resume(returning: fixResponse)
                            }else if ResponseData.self is NtkNever.Type {
                                // 用户期待的数据类型就是Never，啥都没有
                                let fixResponse = NtkResponse(code: responseData.code, data: NtkNever() as! ResponseData, msg: responseData.msg, response: response, request: self.request!)
                                continuatuon.resume(returning: fixResponse)
                            }else {
                                // 后端code验证成功，但是没有得到匹配的数据类型
                                throw NtkError.responseDataEmpty
                            }  
                        } catch {
                            continuatuon.resume(throwing: error)
                        }
                    case .failure(let moyaError):
                        continuatuon.resume(throwing: moyaError)
                    }
                }
            }
            return response
        } catch let error as MoyaError {
            if case .jsonMapping(let response) = error {
                throw NtkError.jsonInvalid(request!, response)
            }
            if case let .objectMapping(error, response) = error {
                throw NtkError.decodeInvalid(error, request!, response)
            }
            throw NtkError.other(error)
        }
    }
    
    func execute<ResponseData>() async throws -> NtkResponse<ResponseData> {
        fatalError("Swift都应该使用Codable进行模型解析")
    }
    
    func loadCache<ResponseData: Decodable>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        assert(request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: request!, storage: storage, cacheConfig: nil)
        let response: NtkResponse<ResponseData>? = try await cacheUtil.loadData()
        return response
    }
    
    func loadCache<ResponseData>(_ storage: any iNtkCacheStorage) async throws -> NtkResponse<ResponseData>? {
        fatalError("Swift都应该使用Codable进行模型解析")
    }
    
    func hasCacheData(_ storage: any iNtkCacheStorage) -> Bool {
        assert(request != nil, "iNtkClient request must not nil")
        let cacheUtil = NtkNetworkCache<Keys>(request: request!, storage: storage, cacheConfig: nil)
        return cacheUtil.hasData()
    }
}

