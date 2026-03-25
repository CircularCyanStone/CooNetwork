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

/// payload pipeline 入口的轻量结构 gate。
///
/// 这里只负责：
/// - 接受顶层 object / array
/// - 拒绝顶层 scalar
/// - 对 Foundation 容器做顶层浅桥接
///
/// 不对整棵 payload 做递归归一化；更深层的结构解释由 transformer / decoder 按需处理。
enum PayloadRootGate {
    static func normalizeRoot(_ raw: Any) throws -> NtkDynamicData? {
        if isTopLevelScalar(raw) {
            return nil
        }

        if let object = normalizeObjectRoot(raw) {
            return NtkDynamicData(dictionary: object)
        }

        if let array = normalizeArrayRoot(raw) {
            return NtkDynamicData(array: array)
        }

        return nil
    }

    private static func isTopLevelScalar(_ raw: Any) -> Bool {
        switch raw {
        case is String, is Bool, is Int, is Double, is NSNull, is NSString, is NSNumber:
            return true
        default:
            return false
        }
    }

    private static func normalizeObjectRoot(_ raw: Any) -> [String: any Sendable]? {
        raw as? [String: any Sendable]
    }

    private static func normalizeArrayRoot(_ raw: Any) -> [any Sendable]? {
        raw as? [any Sendable]
    }
}
