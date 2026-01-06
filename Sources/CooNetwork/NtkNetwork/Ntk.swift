//
//  Ntk.swift
//  NtkNetwork
//
//  Created by 李奇奇 on 2025/9/3.
//

import Foundation

typealias NtkBool<Keys: iNtkResponseMapKeys> = Ntk<Bool, Keys>

@NtkActor
public final class Ntk<ResponseData: Sendable, Keys: iNtkResponseMapKeys> {
    
    public static func with(_ client: any iNtkClient, request: iNtkRequest, dataParsingInterceptor: iNtkInterceptor, validation: iNtkResponseValidation) -> NtkNetwork<ResponseData> {
        var _validation: iNtkResponseValidation
        if let requestValidation = request as? iNtkResponseValidation {
            _validation = requestValidation
        }else {
            _validation = validation
        }
        var net = NtkNetwork<ResponseData>.with(client, request: request, dataParsingInterceptor: dataParsingInterceptor, validation: _validation)
        
        if request.requestConfiguration != nil {
            net = net.addInterceptor(NtkCacheSaveInterceptor())
        }
        return net
    }
    
}
