//
//  AFResponseMapKeys.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/01/10.
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif

/// 后端返回的JSON结构可能出现不一致的情况，该类型定义了默认的JSON结构的字段映射。
public struct AFResponseMapKeys : iNtkResponseMapKeys {
    /// 状态码字段键名
    public static var code: String {
        "retCode"
    }

    /// 数据字段键名
    public static var data: String {
        "data"
    }

    /// 消息字段键名
    public static var msg: String {
        "retMsg"
    }
}
