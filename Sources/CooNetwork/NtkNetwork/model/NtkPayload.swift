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
    /// 该步骤只保证输入在结构上可进入 normalize → transform → decode 流程，
    /// 不保证 payload 符合某个业务 envelope。header 提取、decode 与 validation
    /// 由后续阶段决定。
    public static func normalize(from raw: Any) throws -> NtkPayload {
        if let data = raw as? Data {
            return .data(data)
        }

        guard let dynamic = try StrictPayloadNormalizer.normalizeRoot(raw) else {
            throw NtkError.typeMismatch
        }

        return .dynamic(dynamic)
    }
}
