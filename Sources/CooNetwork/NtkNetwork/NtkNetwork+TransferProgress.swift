//
//  NtkNetwork+TransferProgress.swift
//  CooNetwork
//
//  Created by CooNetwork on 2026/03/20.
//

import Foundation

public let NtkRequestTransferProgressKey = "transferProgress"

// MARK: - 链式 API（通道 b）

extension NtkNetwork {
    /// 挂载传输进度回调（调用时临时挂载，优先级高于协议属性）
    /// Upload/Download 通用
    @discardableResult
    public func onTransferProgress(
        _ handler: @escaping @Sendable (NtkTransferProgress) -> Void
    ) -> Self {
        setRequestValue(handler, forKey: NtkRequestTransferProgressKey)
        return self
    }
}

// MARK: - AsyncStream（通道 c）

extension NtkNetwork {
    /// 带进度的请求，返回 AsyncThrowingStream
    /// Upload 请求返回上传进度，Download 请求返回下载进度
    /// 与 requestWithCache() 同为流式 API 家族
    public func requestWithProgress() -> AsyncThrowingStream<NtkTransferEvent<ResponseData>, Error> {
        // 同步阶段：单次使用保护
        markRequestConsumed()
        let requestID = lock.withLock { mutableRequest.instanceIdentifier.uuidString }

        return AsyncThrowingStream { continuation in
            // 通过链式 API 通道注入进度闭包，桥接到 stream
            self.setRequestValue(
                { @Sendable (progress: NtkTransferProgress) in
                    continuation.yield(.progress(progress))
                } as @Sendable (NtkTransferProgress) -> Void,
                forKey: NtkRequestTransferProgressKey
            )

            let task = Task {
                do {
                    let result = try await self.getOrCreateExecutor().execute() as NtkResponse<ResponseData>
                    continuation.yield(.completed(result))
                    continuation.finish()
                } catch {
                    logger.error(
                        "带进度请求执行失败：requestID=\(requestID)，原因=\(String(reflecting: type(of: error)))；影响=结果流以错误结束。",
                        category: .network
                    )
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable termination in
                switch termination {
                case .cancelled:
                    logger.debug(
                        "带进度请求流已取消：requestID=\(requestID)；影响=取消底层任务，不再产出进度或结果。",
                        category: .network
                    )
                    task.cancel()
                case .finished:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
