//
//  UserInfo.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/18.
//

import UIKit
import CodableWrappers

@objcMembers
class UserInfo: NSObject, Codable {

    @FallbackDecoding<EmptyString>
    var userName: String

    let age: Int
    
    let school: String
    
    @FallbackDecoding<EmptyArray>
    var books: [String]
}
