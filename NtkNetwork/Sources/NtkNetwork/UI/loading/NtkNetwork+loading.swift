//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

// 是否显示loading
let NtkRequestExtraLoadingKey = "loading"
let NtkRequestExtraLoadingTextKey = "loading_text"

extension NtkNetwork {
    public func hud(_ show: Bool) -> Self {
        operation.request[NtkRequestExtraLoadingKey] = show
        return self
    }
    
    public func loadingText(_ text: String) -> Self {
        operation.request[NtkRequestExtraLoadingKey] = true
        operation.request[NtkRequestExtraLoadingTextKey] = text
        return self
    }
}
