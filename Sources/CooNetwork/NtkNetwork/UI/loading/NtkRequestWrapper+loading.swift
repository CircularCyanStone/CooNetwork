//
//  NtkRequestWrapper+loading.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

extension NtkMutableRequest {
    
    // 接口是否需要显示loading
    var showLoading: Bool {
        (extraData[NtkRequestExtraLoadingKey] as? Bool) ?? false
    }
    
    // 接口需要显示loading文字
    var loadingText: String? {
        extraData[NtkRequestExtraLoadingTextKey] as? String
    }
}
