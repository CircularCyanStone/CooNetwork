//
//  TFN.swift
//  TAIChat
//
//  Created by 李奇奇 on 2025/7/27.
//

import Foundation

typealias TFNDefault<DataType: Sendable & Decodable> = TFN<DataType, TFNResponseMapKeys>

typealias TFNBool = TFN<Bool, TFNResponseMapKeys>

@TFNActor
final class TFN<DataType: Sendable & Decodable, Key: iTFNResponseMapKeys>: Sendable {
    
    static func with(_ client: iTFNClient, request: iTFNRequest, dataParsingInterceptor: iTFNInterceptor) -> TFNNetwork<DataType> {
        let interceptors: [any iTFNInterceptor] = []
        var network = TFNNetwork<DataType>(client: client, interceptors: interceptors)
        network = network.addDataParsingInterceptor(dataParsingInterceptor)
        network = network.with(request)
        return network
    }
    
    static func withAlamofire(_ request: iTFNRequest) -> TFNNetwork<DataType> {
        let client = TFNAlamofireClient()
        return with(client, request: request, dataParsingInterceptor: TFNDataParsingInterceptor<DataType, Key>())
    }
}
