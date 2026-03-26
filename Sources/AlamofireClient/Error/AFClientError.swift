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

extension ClientFailure.AF {
    static func fromAFError(
        _ error: AFError,
        request: iNtkRequest?,
        clientResponse: NtkClientResponse? = nil
    ) -> ClientFailure.AF {
        .init(
            reason: .afError,
            context: .init(
                request: request,
                clientResponse: clientResponse,
                underlyingError: error,
                message: error.errorDescription ?? error.localizedDescription
            )
        )
    }
}
