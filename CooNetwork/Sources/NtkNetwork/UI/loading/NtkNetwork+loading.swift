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
    public func hud(_ show: Bool = true) -> Self {
        setRequestValue(show, forKey: NtkRequestExtraLoadingKey)
        return self
    }
    
    public func loadingText(_ text: String) -> Self {
        setRequestValue(true, forKey: NtkRequestExtraLoadingKey)
        setRequestValue(text, forKey: NtkRequestExtraLoadingTextKey)
        return self
    }
}
