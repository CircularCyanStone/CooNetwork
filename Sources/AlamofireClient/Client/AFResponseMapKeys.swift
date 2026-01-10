//
//  AFResponseMapKeys.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
import CooNetwork

/// 后端返回的JSON结构可能出现不一致的情况，该类型定义了默认的JSON结构的字段映射。
public struct AFResponseMapKeys : iNtkResponseMapKeys {
    public static var code: String {
        "retCode"
    }
    
    public static var data: String {
        "data"
    }
    
    public static var msg: String {
        "retMsg"
    }
}
