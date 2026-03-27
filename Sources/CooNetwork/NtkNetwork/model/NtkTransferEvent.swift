// Sources/CooNetwork/NtkNetwork/model/NtkTransferEvent.swift
import Foundation

/// 传输事件（上传/下载通用）
/// 用于 AsyncThrowingStream 的 yield 类型
public enum NtkTransferEvent<ResponseData: Sendable>: Sendable {
    /// 传输进度
    case progress(NtkTransferProgress)
    /// 传输完成
    case completed(NtkResponse<ResponseData>)
}
