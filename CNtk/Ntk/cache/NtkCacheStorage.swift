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
class NtkCacheStorage {
    let request: iNtkRequest
    
    init(request: iNtkRequest) {
        self.request = request
    }
    
    /**
     * 存储数据到缓存
     * @param metaData 缓存元数据
     * @param key 缓存键
     * @return 是否存储成功
     */
    func setData(metaData: NtkCacheMeta, key: String) async -> Bool {
        fatalError("Subclasses must implement setData")
    }
    
    /**
     * 从缓存获取数据
     * @param key 缓存键
     * @return 缓存的元数据，如果不存在则返回nil
     */
    func getData(key: String) async -> NtkCacheMeta? {
        fatalError("Subclasses must implement getData")
    }
    
    func hasData(key: String) -> Bool {
        fatalError("sub class should implement this method")
    }
}