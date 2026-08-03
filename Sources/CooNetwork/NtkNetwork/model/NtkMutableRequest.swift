//
//  NtkMutableRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

/// 在 `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 中构建请求的值类型。
/// 进入 `NtkInterceptorContext` 后只能作为只读请求快照使用。
public struct NtkMutableRequest: iNtkRequest {

    // MARK: - 原始请求属性（不可变）

    /// 原始请求对象
    public let originalRequest: iNtkRequest

    /// 请求实例标识，用于区分同语义下的不同请求实例
    public let instanceIdentifier: UUID

    /// 取消状态（引用类型，用于跨组件共享状态）
    public var isCancelledRef: NtkCancellableState?

    // MARK: - 可变属性（直接存储，与iNtkRequest使用习惯一致）

    /// 请求参数，可直接修改
    public var parameters: [String: Sendable]?

    /// 请求头，可直接修改
    public var headers: [String: String]?

    /// 当前执行快照使用的请求超时。
    public internal(set) var timeout: TimeInterval

    /// 请求级附加元数据。
    ///
    /// 调用方可以在请求执行前写入；请求修改拦截器可以在
    /// `iNtkRequestModifyingInterceptor.modifyRequest(_:)` 阶段读取或修改。
    /// 请求构建完成后，该数据随只读请求快照进入普通拦截器链。
    ///
    /// 该数据与 `NtkInterceptorContext.extraData` 分属不同阶段，框架不会在二者之间
    /// 自动同步或回写。
    public var extraData: [String: Sendable] = [:]

    /// Header 逻辑名称到字段级身份覆盖的映射；只存储显式 included/excluded。
    private var headerIdentityParticipation: [String: NtkIdentityParticipation] = [:]

    /// 参数精确名称到字段级身份覆盖的映射；只存储显式 included/excluded。
    private var parameterIdentityParticipation: [String: NtkIdentityParticipation] = [:]

    /// 只参与本地身份、不进入请求 payload 的稳定业务维度。
    private var storedIdentityComponents: [String: String] = [:]

    /// 当前稳定业务身份维度的只读快照。
    internal var identityComponents: [String: String] {
        storedIdentityComponents
    }

    // MARK: - 初始化

    /// 使用原始请求初始化可变请求包装器
    /// - Parameter request: 原始请求对象
    public init(_ request: iNtkRequest) {
        self.originalRequest = request
        self.instanceIdentifier = UUID()
        // 复制原始请求的参数和头部到可变属性中
        self.parameters = request.parameters
        self.headers = request.headers
        self.timeout = request.timeout
    }

    // MARK: - iNtkRequest 协议实现

    public var baseURL: URL? {
        return originalRequest.baseURL
    }

    public var path: String {
        return originalRequest.path
    }

    public var method: NtkHTTPMethod {
        return originalRequest.method
    }

    public var requestConfiguration: NtkRequestConfiguration? {
        return originalRequest.requestConfiguration
    }

    /// 原始请求声明的响应缓存配置。
    ///
    /// 该值只读转发；`nil` 表示不读写缓存。配置不负责身份字段过滤，缓存时长与响应写入
    /// 资格也不改变资源 key；无效时长只关闭缓存，网络继续。
    public var cacheConfiguration: NtkCacheConfiguration? {
        originalRequest.cacheConfiguration
    }

    /// 原始请求声明的请求级身份策略。
    ///
    /// 该值只读转发；`nil` 继承 executor 创建时冻结的全局策略，非 `nil` 完整替换而不合并。
    /// 排除鉴权字段时仍须保留稳定的 user/tenant 隔离，策略失败只关闭本次缓存和去重。
    public var requestIdentityPolicy: NtkRequestIdentityPolicy? {
        originalRequest.requestIdentityPolicy
    }

    // MARK: - 便捷方法

    /// 返回指定参数的字段级身份参与状态。
    ///
    /// 参数键区分大小写；没有显式覆盖时返回 `.automatic` 并继承有效策略。
    internal func identityParticipation(forParameter key: String) -> NtkIdentityParticipation {
        parameterIdentityParticipation[key] ?? .automatic
    }

    /// 返回指定 Header 逻辑名称的字段级身份参与状态。
    ///
    /// Header 名称按小写匹配；没有显式覆盖时返回 `.automatic` 并继承有效策略。
    internal func identityParticipation(forHeader key: String) -> NtkIdentityParticipation {
        headerIdentityParticipation[key.lowercased()] ?? .automatic
    }

    /// 更新 Header 字段级覆盖；automatic 通过删除条目恢复策略继承。
    private mutating func setHeaderParticipation(
        _ participation: NtkIdentityParticipation,
        for key: String
    ) {
        let normalizedKey = key.lowercased()
        switch participation {
        case .automatic:
            headerIdentityParticipation.removeValue(forKey: normalizedKey)
        case .included, .excluded:
            headerIdentityParticipation[normalizedKey] = participation
        }
    }

    /// 更新参数字段级覆盖；automatic 通过删除条目恢复策略继承。
    private mutating func setParameterParticipation(
        _ participation: NtkIdentityParticipation,
        for key: String
    ) {
        switch participation {
        case .automatic:
            parameterIdentityParticipation.removeValue(forKey: key)
        case .included, .excluded:
            parameterIdentityParticipation[key] = participation
        }
    }

    /// 添加或替换单个请求参数，并完整替换该字段的身份参与状态。
    ///
    /// 参数键区分大小写，值始终保留在真实请求 payload 中；`identity` 只改变缓存与去重共用
    /// 的本地身份投影，默认 `.automatic` 继承有效策略。将 token 等字段标为 `.excluded`
    /// 可能移除主体隔离，必须用稳定参数或 identity component 区分 user/tenant；该操作本身
    /// 不会导致网络请求失败。
    /// - Parameters:
    ///   - key: 参数键
    ///   - value: 参数值
    ///   - identity: 字段身份参与状态，默认 `.automatic`。
    public mutating func addParameter(
        key: String,
        value: Sendable,
        identity: NtkIdentityParticipation = .automatic
    ) {
        if parameters == nil {
            parameters = [:]
        }
        parameters?[key] = value
        setParameterParticipation(identity, for: key)
    }

    /// 按参数名稳定顺序批量添加参数，并为每个字段完整替换同一身份状态。
    ///
    /// 参数键区分大小写，所有值仍会发送；默认 `.automatic` 继承有效策略。统一排除动态字段
    /// 时，调用方仍负责保留稳定的 user/tenant 隔离；后续身份规范化失败时，由执行器关闭
    /// 本次缓存和去重，网络请求继续。
    /// - Parameters:
    ///   - parameters: 要添加的参数字典。
    ///   - identity: 应用于全部字段的身份参与状态，默认 `.automatic`。
    public mutating func addParameters(
        _ parameters: [String: Sendable],
        identity: NtkIdentityParticipation = .automatic
    ) {
        for key in parameters.keys.sorted() {
            if let value = parameters[key] {
                addParameter(key: key, value: value, identity: identity)
            }
        }
    }

    /// 全量替换参数，并清除所有旧参数身份元数据后为新字段应用同一状态。
    ///
    /// 新参数仍完整发送，默认 `.automatic` 表示全部继承有效策略。本操作不影响 Header 或
    /// identity component；若将所有新参数排除，调用方必须另行保留稳定主体隔离。身份处理
    /// 失败应由执行器降级关闭缓存与去重，网络继续。
    /// - Parameters:
    ///   - newParameters: 用于替换现有 payload 参数的字典。
    ///   - identity: 应用于全部新字段的身份参与状态，默认 `.automatic`。
    public mutating func setParameter(
        _ newParameters: [String: Sendable],
        identity: NtkIdentityParticipation = .automatic
    ) {
        parameters = newParameters
        parameterIdentityParticipation.removeAll()
        for key in newParameters.keys.sorted() {
            setParameterParticipation(identity, for: key)
        }
    }

    /// 添加或替换单个请求头，并完整替换该逻辑字段的身份参与状态。
    ///
    /// Header 名称按 HTTP 语义大小写不敏感：写入前会删除所有同名变体，再保留本次传入的
    /// key/value。值始终发送；`identity` 只影响本地身份投影，默认 `.automatic` 继承策略。
    /// 排除鉴权 Header 时必须用稳定字段或 identity component 隔离 user/tenant，避免跨主体
    /// 缓存或去重共享。
    /// - Parameters:
    ///   - key: Header 名称。
    ///   - value: Header 值。
    ///   - identity: 字段身份参与状态，默认 `.automatic`。
    public mutating func addHeader(
        key: String,
        value: String,
        identity: NtkIdentityParticipation = .automatic
    ) {
        if headers == nil {
            headers = [:]
        }
        let normalizedKey = key.lowercased()
        let existingKeys = headers?.keys.filter { $0.lowercased() == normalizedKey } ?? []
        for existingKey in existingKeys {
            headers?.removeValue(forKey: existingKey)
        }
        headers?[key] = value
        setHeaderParticipation(identity, for: key)
    }

    /// 按名称稳定顺序批量添加 Header，并为每个逻辑字段完整替换同一身份状态。
    ///
    /// Header 名称大小写不敏感；输入含同名不同大小写键时，排序后最后处理的条目确定生效。
    /// 所有值仍会发送，默认 `.automatic` 继承策略。排除鉴权字段时调用方仍负责稳定主体隔离。
    /// - Parameters:
    ///   - newHeaders: 要添加的 Header 字典。
    ///   - identity: 应用于全部 Header 的身份参与状态，默认 `.automatic`。
    public mutating func addHeaders(
        _ newHeaders: [String: String],
        identity: NtkIdentityParticipation = .automatic
    ) {
        for key in newHeaders.keys.sorted() {
            if let value = newHeaders[key] {
                addHeader(key: key, value: value, identity: identity)
            }
        }
    }

    /// 添加或替换只参与本地身份的稳定业务维度。
    ///
    /// component 不会进入参数、Header 或 `extraData`，同 key 后写覆盖且 key 区分大小写。
    /// 适合显式隔离 userID、tenantID 等主体；默认没有 component，移除后由调用方承担潜在
    /// 跨主体碰撞风险。该值不影响真实网络请求。
    /// - Parameters:
    ///   - key: 身份维度名称，区分大小写。
    ///   - value: 稳定、确定的身份维度值。
    public mutating func addIdentityComponent(key: String, value: String) {
        storedIdentityComponents[key] = value
    }

    /// 删除指定的本地身份维度。
    ///
    /// 该操作不改变真实请求 payload；删除 user/tenant 隔离维度可能使不同主体产生相同缓存键
    /// 或去重键，调用方必须确认其他稳定字段仍能隔离主体。不存在的 key 会安全忽略。
    /// - Parameter key: 要删除的身份维度名称，区分大小写。
    public mutating func removeIdentityComponent(key: String) {
        storedIdentityComponents.removeValue(forKey: key)
    }

    /// 精确移除指定参数及其字段级身份覆盖。
    ///
    /// 参数键区分大小写；移除会同时改变真实 payload 和本地身份。不存在的 key 安全忽略，
    /// 且不会影响 Header 或 identity component。
    /// - Parameter key: 要移除的参数键。
    public mutating func removeParameter(key: String) {
        parameters?.removeValue(forKey: key)
        parameterIdentityParticipation.removeValue(forKey: key)
    }

    /// 按大小写不敏感逻辑名称移除全部同名 Header 及其字段级身份覆盖。
    ///
    /// 移除会同时改变真实请求和本地身份；不存在的逻辑名称安全忽略。鉴权 Header 被移除后，
    /// 服务端行为与主体隔离均可能变化，调用方负责确认这是预期结果。
    /// - Parameter key: 要移除的 Header 逻辑名称。
    public mutating func removeHeader(key: String) {
        let normalizedKey = key.lowercased()
        let existingKeys = headers?.keys.filter { $0.lowercased() == normalizedKey } ?? []
        for existingKey in existingKeys {
            headers?.removeValue(forKey: existingKey)
        }
        headerIdentityParticipation.removeValue(forKey: normalizedKey)
    }

    /// 清空全部参数及参数身份覆盖，但保留 Header 与 identity component。
    ///
    /// 真实 payload 与本地身份会同步失去这些参数；调用方负责确保剩余身份仍能隔离主体。
    public mutating func clearParameters() {
        parameters = nil
        parameterIdentityParticipation.removeAll()
    }

    /// 清空全部 Header 及 Header 身份覆盖，但保留参数与 identity component。
    ///
    /// 真实请求与本地身份会同步失去这些 Header；清除鉴权信息可能改变服务端授权行为。
    public mutating func clearHeaders() {
        headers = nil
        headerIdentityParticipation.removeAll()
    }

    /// 删除已不存在字段的陈旧身份覆盖，供请求冻结前维护元数据不变量。
    ///
    /// 直接修改公开 `headers`/`parameters` 时，新键保持 `.automatic`，仍存在的旧键保留显式
    /// 覆盖，已移除键在此处清理。Header 按小写逻辑名匹配，参数按精确名称匹配；component
    /// 不随 payload 裁剪。
    internal mutating func pruneIdentityMetadata() {
        let existingHeaderNames = Set(headers?.keys.map { $0.lowercased() } ?? [])
        headerIdentityParticipation = headerIdentityParticipation.filter {
            existingHeaderNames.contains($0.key)
        }

        let existingParameterNames = Set(parameters?.keys.map { $0 } ?? [])
        parameterIdentityParticipation = parameterIdentityParticipation.filter {
            existingParameterNames.contains($0.key)
        }
    }

    /// 刷新 executor 创建时需要冻结的请求级计算属性。
    internal mutating func refreshConfigurationSnapshot() {
        timeout = originalRequest.timeout
    }

    /// 写入与任务超时和去重身份共同使用的规范化超时。
    internal mutating func applyEffectiveTimeout(_ value: TimeInterval) {
        timeout = value
    }
}

// MARK: - 下标访问支持

extension NtkMutableRequest {

    /// 通过下标访问 extraData 字典
    /// - Parameter key: 键名
    /// - Returns: 对应的值
    public subscript(key: String) -> Sendable? {
        get {
            return extraData[key]
        }
        set {
            extraData[key] = newValue
        }
    }
}

// MARK: - 调试支持

extension NtkMutableRequest: CustomStringConvertible {

    public var description: String {
        return """
            NtkMutableRequest {
                baseURL: \(baseURL?.absoluteString ?? "nil")
                path: \(path)
                method: \(method)
                parameters: \(parameters ?? [:])
                headers: \(headers ?? [:])
                extraData: \(extraData)
            }
            """
    }
}
