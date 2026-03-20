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
    /// 设置是否显示 Loading
    /// - Parameter show: 是否显示，默认 true
    /// - Returns: 当前实例，支持链式调用
    public func hud(_ show: Bool = true) -> Self {
        setRequestValue(show, forKey: NtkRequestExtraLoadingKey)
        return self
    }

    /// 设置 Loading 文案
    /// - Parameter text: Loading 显示的文字
    /// - Returns: 当前实例，支持链式调用
    public func loadingText(_ text: String) -> Self {
        setRequestValue(true, forKey: NtkRequestExtraLoadingKey)
        setRequestValue(text, forKey: NtkRequestExtraLoadingTextKey)
        return self
    }
}
