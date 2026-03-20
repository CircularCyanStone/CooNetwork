//
//  NtkNetwork+Transfer.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/03/20.
//

import Foundation
#if !COCOAPODS
import CooNetwork
#endif

// MARK: - 链式 API（通道 b）

extension NtkNetwork {
    /// 挂载传输进度回调（调用时临时挂载，优先级高于协议属性）
    /// Upload/Download 通用
    @discardableResult
    public func onTransferProgress(
        _ handler: @escaping @Sendable (NtkTransferProgress) -> Void
    ) -> Self {
        setRequestValue(handler, forKey: "transferProgress")
        return self
    }
}
