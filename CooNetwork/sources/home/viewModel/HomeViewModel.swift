//
//  HomeViewModel.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/8.
//

import Foundation

@MainActor
class HomeViewModel {
    
    var homeNet: NtkNetwork<HomeInfoData>?
    
    func loadData() async throws {
//        let net: NtkNetwork<HomeInfoData> = withRpc(HomeInfoRequest())
//        homeNet = net
//        let response: HomeInfoData = try await net.sendRequest().data
    }
    
    func cancel() {
        homeNet?.cancel()
    }
}
