//
//  NtkOperation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit

@objcMembers
class NtkOperation: NSObject {
    
    // 存储所有注册的拦截器
    private var _interceptors: [iNtkInterceptor] = [] // 内部存储，未排序
    private(set) var interceptors: [iNtkInterceptor] { // 公开属性，返回已排序的拦截器
        get {
            return _interceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _interceptors = newValue
        }
    }

    private var client: iNtkClient
    
    var validation: iNtkResponseValidation?
    
    required
    init(_ client: iNtkClient) {
        self.client = client
        super.init()
    }
    
    
//    func run<ResponseData: Codable>(_ completion: @escaping (_ response: ResponseData) -> Void, failure: @escaping (_ error: NtkError) -> Void) {
//        assert(client.request != nil, "request nil should call the func with(_ request: iNtkRequest) -> Self method first")
//        
//        client.execute { response in
//            do {
//                let responseData: ResponseData = try self.responseHandle(response)
//                completion(responseData)
//            }catch {
//                failure(error as! NtkError)
//            }
//            
//        } failure: { error in
//            failure(error)
//        }
//    }
    
    func run<ResponseData: Codable>() async throws -> NtkResponse<ResponseData> {
        assert(validation != nil, "")
        let context = NtkRequestContext(validation: validation!)
        var currentRequest = client.request!
        do {
            let tmpInterceptors = interceptors
            
            for interceptor in tmpInterceptors {
                currentRequest = try await interceptor.intercept(request: currentRequest, context: context)
            }
            
            client.addRequest(currentRequest)
            
            let response: NtkResponse<ResponseData> = try await client.execute()
            
            var interceptorResponse: any iNtkResponse = response
            
            for interceptor in tmpInterceptors.reversed() {
                interceptorResponse = try await interceptor.intercept(response: interceptorResponse, context: context)
            }
            if let handledResponseData = interceptorResponse as? NtkResponse<ResponseData> {
                return handledResponseData
            }
            return response
        }catch let error as NtkError {
            throw error
        }catch {
            throw error
        }
    }
}
