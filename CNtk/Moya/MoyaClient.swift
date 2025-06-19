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
    
    private(set) var isCancelled: Bool = false
    
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
    
    func execute<ResponseData>(_ completion: @escaping (NtkResponse<ResponseData>) -> Void, failure: (any iNtkError) -> Void) where ResponseData : Decodable, ResponseData : Encodable {
        guard let moyaRequest else {
            return
        }
        cancelToken = provider.request(moyaRequest) { result in
            switch result {
            case .success(let response):
                do {
                    let okResponse = try response.filter(statusCode: 200)
                    let responseModel = try okResponse.map(NtkResponseModel<ResponseData, Keys>.self)
                    let ntkResponse = NtkResponse(code: responseModel.code, data: responseModel.data, msg: responseModel.msg, response: okResponse, request: self.request!)
                    completion(ntkResponse)
                } catch {
//                    failure(error)
                }
            case .failure(let moyaError):
//                failure(error)
                print("===")
            }
        }
    }
    
    func execute() async throws {
        
    }
}

