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
protocol iNtkCacheConfig {
    
    // 缓存时间（毫秒）
    var cacheTime: TimeInterval { get }
    
    // 参数过滤器
    func filterParameter(_ parameter: [String: Any]) -> [String: Any]
    
}
extension iNtkCacheConfig {
    func filterParameter(_ parameter: [String: Any]) -> [String: Any] {
        parameter
    }
}
