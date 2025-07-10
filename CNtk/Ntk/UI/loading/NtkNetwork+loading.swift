//
//  NtkNetwork.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

extension NtkNetwork {
    func hud(_ show: Bool) -> Self {
        operation.requestWrapper[NtkRequestExtraLoadingKey] = show
        return self
    }
}
