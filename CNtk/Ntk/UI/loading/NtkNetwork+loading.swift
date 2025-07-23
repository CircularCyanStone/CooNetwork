//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

// 是否显示loading
let NtkRequestExtraLoadingKey = "loading"

extension NtkNetwork {
    func hud(_ show: Bool) -> Self {
        operation.requestWrapper[NtkRequestExtraLoadingKey] = show
        return self
    }
}
