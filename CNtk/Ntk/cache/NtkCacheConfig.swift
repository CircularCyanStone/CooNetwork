//
//  NtkCacheConfig.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

/**
 * 缓存配置
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */
class NtkCacheConfig {
    // 缓存时间（毫秒）
    let cacheTime: TimeInterval
    // 参数过滤器
    let filterParameter: ((Any) -> Any)?
    
    init(cacheTime: TimeInterval, filterParameter: ((Any) -> Any)? = nil) {
        self.cacheTime = cacheTime
        self.filterParameter = filterParameter
    }
}