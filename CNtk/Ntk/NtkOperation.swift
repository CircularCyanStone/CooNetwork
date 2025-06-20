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
    private var _interceptors: [iNtkInterceptor] = []
    private(set) var interceptors: [iNtkInterceptor] {
        get {
            return _interceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _interceptors = newValue
        }
    }
    
    private var _coreInterceptors: [iNtkInterceptor] = []
    private(set) var coreInterceptors: [iNtkInterceptor] {
        get {
            return _coreInterceptors.sorted { $0.priority > $1.priority }
        }
        set {
            _coreInterceptors = newValue
        }
    }

    private var client: iNtkClient
    
    var validation: iNtkResponseValidation?
    
    required
    init(_ client: iNtkClient) {
        self.client = client
        super.init()
        embededCoreInterceptor()
    }
    
    private func addCoreInterceptor(_ i: iNtkInterceptor) {
        _coreInterceptors.append(i)
    }
    
    private func embededCoreInterceptor() {
        addCoreInterceptor(NtkValidationInterceptor())
    }
}

extension NtkOperation {
    
    func addInterceptor(_ i: iNtkInterceptor) {
        _interceptors.append(i)
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
        let context = NtkRequestContext(validation: validation!, client: client)
        let tmpInterceptors = coreInterceptors + interceptors
        let realApiHandle: NtkDefaultApiRequestHandler<ResponseData> = NtkDefaultApiRequestHandler()
        let realChainManager = NtkInterceptorChainManager(interceptors: tmpInterceptors, finalHandler: realApiHandle)
        
        do {
            let response = try await realChainManager.execute(context: context)
            if let response = response as? NtkResponse<ResponseData> {
                return response
            }else {
                throw NtkError.retDataTypeError
            }
        }catch let error as NtkError {
            throw error
        }catch {
            throw error
        }
    }
}
