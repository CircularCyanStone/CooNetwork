//
//  EWLoginRequest.swift
//  OCExample
//
//  Created by 李奇奇 on 2026/1/7.
//

import UIKit
import CooNetwork


final class EWLoginRequest: NSObject, Sendable {

    let userId: String
    
    @objc
    required init(_ userId: String) {
        self.userId = userId
        super.init()
    }
}

extension EWLoginRequest: iNtkRequest {
    var path: String {
        ""
    }
    
    var parameters: [String : any Sendable]? {
        [
            "userId" : userId
        ]
    }
}


