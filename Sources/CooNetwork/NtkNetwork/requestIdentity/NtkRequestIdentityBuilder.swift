import CryptoKit
import Foundation

/// 把“请求修改完成后的快照”转换成缓存与去重共同使用的稳定请求 key。
///
/// 该类型刻意保持无状态：同一个 request + policy 必须在任意线程、任意进程启动中得到相同
/// key。它负责决定哪些字段写入 key 并组织顶层结构；具体参数值如何变成无歧义字节由
/// `NtkRequestIdentityEncoder` 负责。缓存和任务管理器都不能复制这套逻辑，否则一次请求
/// 可能出现缓存 key 与去重 key 不一致。
struct NtkRequestIdentityBuilder {

    /// 完成一次请求 key 构建。
    ///
    /// 调用时机位于所有 `iNtkRequestModifyingInterceptor` 之后，因此这里看到的是实际准备
    /// 发送的 Header/参数及修改器添加的字段 key rule。执行步骤为：
    /// 1. 按 request identity rule 与 policy 选择 Header 和参数；
    /// 2. 按固定 tag 顺序编码资源维度；
    /// 3. 对稳定编码后的字节执行 SHA-256，并加上算法版本前缀。
    ///
    /// 返回值只描述资源，不包含 cacheTime、shouldCache、响应类型、timeout 或 namespace。
    /// 后四类执行语义由缓存配置或 `NtkDeduplicationKey` 在下游分别处理。
    static func build(
        request: NtkMutableRequest,
        policy: NtkRequestIdentityPolicy
    ) throws -> NtkRequestIdentity {
        // 先完成字段筛选再编码，保证 encoder 只关心“值怎样稳定表示”，不需要了解策略优先级。
        let headers = try headersForRequestIdentity(request: request, policy: policy)
        let parameters = try parametersForRequestIdentity(request: request, policy: policy)

        var encoder = NtkRequestIdentityEncoder()

        // 顶层 tag 是持久化协议的一部分：
        // 1 method，2 可选 baseURL，3 path，4 headers，5 parameters，6 本地 request identity values。
        // 即使两个 payload 文本碰巧相同，字段 tag 和长度帧也能阻止跨字段边界碰撞。
        // 调整顺序、tag 或字段集合时必须升级下面的持久化 key 版本。
        encoder.appendStringField(tag: 1, value: request.method.rawValue)
        encoder.appendOptionalStringField(tag: 2, value: request.baseURL?.absoluteString)
        encoder.appendStringField(tag: 3, value: request.path)
        encoder.appendStringDictionaryField(tag: 4, value: headers)
        try encoder.appendValueDictionaryField(tag: 5, value: parameters, path: "parameters")
        encoder.appendStringDictionaryField(tag: 6, value: request.requestIdentityValues)

        // key 使用固定小写十六进制，既可以跨进程持久化，又不暴露原始字段拼接文本。
        // `ntk-identity-v2-` 是已经落盘的缓存格式版本。虽然 API 已改名为 RequestIdentity，但只改
        // 这个前缀会让升级后的应用无法命中全部旧缓存，因此本次命名重构刻意保留它。只有编码
        // 协议真的变化时才应升级版本，并让旧 key 交给 storage 的既有淘汰机制清理。
        let hash = SHA256.hash(data: encoder.data)
            .map { String(format: "%02x", $0) }
            .joined()
        return NtkRequestIdentity(value: "ntk-identity-v2-\(hash)")
    }
}

private extension NtkRequestIdentityBuilder {

    /// 选出写入请求 key 的 Header，不修改 `request.headers`。
    ///
    /// Header 需要同时处理两种大小写规则：字段 key rule 和 policy 排除按 HTTP 语义
    /// 大小写不敏感；真正编码前也统一为小写，确保 `Authorization` 与 `authorization`
    /// 得到同一个 key。Header value 不做隐式裁剪或大小写转换，需要业务转换时必须通过
    /// `transformHeaders` 明确声明。
    static func headersForRequestIdentity(
        request: NtkMutableRequest,
        policy: NtkRequestIdentityPolicy
    ) throws -> [String: String] {
        // included 与 automatic 必须分桶。转换闭包只允许看 automatic，避免全局规则把调用方
        // 显式要求保留的字段删掉，也避免它读取调用方显式排除的凭证。
        var included: [String: String] = [:]
        var automatic: [String: String] = [:]

        for (key, value) in request.headers ?? [:] {
            switch request.requestIdentityRuleForHeader(named: key) {
            case .exclude:
                continue
            case .include:
                included[key] = value
            case .automatic:
                if !policy.excludedHeaderNames.contains(key.lowercased()) {
                    automatic[key] = value
                }
            }
        }

        let transformed: [String: String]
        do {
            transformed = try policy.transformHeaders?(automatic) ?? automatic
        } catch {
            // 只保留错误类型，不拼接 error.localizedDescription，防止业务转换闭包把 token、
            // 签名或其他敏感字段放进错误文本后被框架日志带出。
            throw BuildError.transformationFailed(
                section: .headers,
                errorType: String(reflecting: type(of: error))
            )
        }

        var merged = transformed
        let transformedKeys = Set(transformed.keys.map { $0.lowercased() })
        for (key, value) in included {
            // 转换闭包可以创建新的 key 字段；若它创建了与 included 同名的 Header，框架无法
            // 在“不允许转换结果覆盖 included”和“字典只能保留一个值”之间安全选择，故失败。
            guard !transformedKeys.contains(key.lowercased()) else {
                throw BuildError.keyConflict(section: .headers, key: key)
            }
            merged[key] = value
        }

        var headersByLowercaseName: [String: String] = [:]
        for (key, value) in merged {
            // 转换闭包的输出不一定还是合法 HTTP 名称，所以在生成持久化请求 key 前重新验证。
            guard isValidHeaderName(key) else {
                throw BuildError.invalidHeaderName(key)
            }
            let lowercasedKey = key.lowercased()
            // Swift Dictionary 可以同时容纳 X-Key 与 x-key，但 HTTP 认为它们是同一字段。
            // 依赖遍历顺序覆盖会造成请求 key 不稳定，因此转成小写后发现重复必须明确失败。
            guard headersByLowercaseName[lowercasedKey] == nil else {
                throw BuildError.duplicateHeaderName(lowercasedKey)
            }
            headersByLowercaseName[lowercasedKey] = value
        }
        return headersByLowercaseName
    }

    /// 选出写入请求 key 的参数，不修改真正发送的 payload。
    ///
    /// 参数名属于业务协议，始终区分大小写，因此 `token`、`Token` 与 `tokenValue` 是三个
    /// 不同字段。参数值不在此处字符串化；筛选完成后由 request identity encoder 递归保留其类型、
    /// 字典结构和数组顺序。
    static func parametersForRequestIdentity(
        request: NtkMutableRequest,
        policy: NtkRequestIdentityPolicy
    ) throws -> [String: any Sendable] {
        // 与 Header 相同，显式字段绕过转换闭包；两个分桶在转换闭包返回后才合并。
        var included: [String: any Sendable] = [:]
        var automatic: [String: any Sendable] = [:]

        for (key, value) in request.parameters ?? [:] {
            switch request.requestIdentityRuleForParameter(named: key) {
            case .exclude:
                continue
            case .include:
                included[key] = value
            case .automatic:
                if !policy.excludedParameterNames.contains(key) {
                    automatic[key] = value
                }
            }
        }

        let transformed: [String: any Sendable]
        do {
            transformed = try policy.transformParameters?(automatic) ?? automatic
        } catch {
            // 失败诊断只记录 section 和错误动态类型，不读取可能包含敏感值的错误描述。
            throw BuildError.transformationFailed(
                section: .parameters,
                errorType: String(reflecting: type(of: error))
            )
        }

        var merged = transformed
        for (key, value) in included {
            // 参数按精确 key 判断碰撞；转换闭包不得通过输出同名 key 覆盖显式 included 值。
            guard merged[key] == nil else {
                throw BuildError.keyConflict(section: .parameters, key: key)
            }
            merged[key] = value
        }
        return merged
    }

    /// 按 RFC token 字符集合验证 Header 名称。
    ///
    /// 这里只验证名称，不验证值；目的不是重新实现 HTTP 客户端校验，而是保证请求 key 构建器不会为
    /// 转换闭包生成的非法或非 ASCII 名称建立可持久化 key。返回 false 会触发 key 降级，
    /// 不会在此处修改真实请求。
    static func isValidHeaderName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let punctuation = Set("!#$%&'*+-.^_`|~".utf8)
        return name.utf8.allSatisfy {
            $0 <= 127 && (
                (48...57).contains($0) ||
                (65...90).contains($0) ||
                (97...122).contains($0) ||
                punctuation.contains($0)
            )
        }
    }
}
