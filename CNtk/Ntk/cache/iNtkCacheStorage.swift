//
//  NtkCacheStorage.swift
//  CooNetwork
//
//  Created by Coo on 2025/1/2.
//

import Foundation

/**
 * Ntk网络缓存工具：缓存功能的抽象类
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */
protocol iNtkCacheStorage: Sendable {
   
    
    func addRequest(_ request: iNtkRequest)
    
    /**
     * 存储数据到缓存
     * @param metaData 缓存元数据
     * @param key 缓存键
     * @return 是否存储成功
     */
    func setData(metaData: NtkCacheMeta, key: String) async -> Bool
    
    /**
     * 从缓存获取数据
     * @param key 缓存键
     * @return 缓存的元数据，如果不存在则返回nil
     */
    func getData(key: String) async -> NtkCacheMeta?
    
    /// 判断磁盘里是否有缓存
    func hasData(key: String) -> Bool
}
