//
//  NtkError_Rpc.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/4.
//

import Foundation
import NtkNetwork

extension NtkError {
    enum Rpc: Error {
        case responseEmpty
        case responseTypeError
        case unknown(msg: String)
    }
}
