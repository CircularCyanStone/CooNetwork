import Foundation

public enum NtkPayload: Sendable {
    case data(Data)
    case dynamic(NtkDynamicData)

    /// 将客户端原始响应收敛为可进入 payload pipeline 的统一中间层。
    ///
    /// 这里定义的是“结构边界”，不是业务协议边界：
    /// - 接受原始 `Data`
    /// - 接受顶层 object / array 这类结构化 payload
    /// - 拒绝顶层 scalar（`String` / `number` / `bool` / `null`）这类 leaf value
    ///
    /// 该步骤只保证输入在结构上可进入 normalize → transform → decode 流程。
    /// 对结构化 payload，仅校验顶层 root 为 object / array；不对整棵树做递归归一化。
    /// 更深层的结构解释，以及字段语义的收敛，由后续 transformer / decoder 决定。
    public static func normalize(from raw: Any) throws -> NtkPayload {
        if let data = raw as? Data {
            return .data(data)
        }

        guard let dynamic = try PayloadRootGate.normalizeRoot(raw) else {
            throw NtkError.typeMismatch
        }

        return .dynamic(dynamic)
    }
}
