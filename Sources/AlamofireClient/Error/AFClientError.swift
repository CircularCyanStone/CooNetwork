//
//  AFClientError.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif
import Alamofire

public extension NtkError.Client {
    public enum AF: Error, Sendable {
        case requestFailed
    }

    static func fromAFError(
        _ error: AFError,
        request: iNtkRequest?,
        clientResponse: NtkClientResponse? = nil
    ) -> NtkError.Client {
        .external(
            reason: AF.requestFailed,
            request: request,
            clientResponse: clientResponse,
            underlyingError: error,
            message: error.errorDescription ?? error.localizedDescription
        )
    }
}
