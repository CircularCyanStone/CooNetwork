//
//  NtkMutableRequest.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/10.
//

import Foundation

/// 请求修改拦截器用于生成“最终网络请求”的可变包装器。
///
/// 这个类型同时维护两类数据，但二者用途不同：
/// - `headers` 和 `parameters` 是真实请求内容，后续会交给网络层发送；
/// - `requestIdentityState` 是缓存与请求去重使用的本地规则，不会发送给服务器。
///
/// 两类数据必须同步变化。例如删除一个 Header 时，它对应的 Request Identity 规则也必须删除，
/// 否则以后重新添加同名 Header 时可能错误复用旧规则。因此 `headers` 和 `parameters` 对外
/// 只读，修改器必须通过本类型提供的 `set`、`merge`、`remove` 方法修改请求。每个方法都会
/// 在一次操作中同时更新真实请求内容和本地 Request Identity 规则。
public struct NtkMutableRequest: iNtkRequest {

    /// 创建这个可变包装器时传入的原始请求。
    ///
    /// `baseURL`、`path`、`method`、缓存配置和 Request Identity 策略都从这里读取；请求修改器
    /// 只能修改本类型明确开放的运行时字段，不能把请求切换成另一条接口。
    public let originalRequest: iNtkRequest

    /// 当前执行实例的唯一标识。
    ///
    /// 当缓存或请求去重不可用时，框架使用它隔离两次独立执行，避免把“内容相同的两个请求”
    /// 误认为同一个正在执行的任务。它不是缓存键，也不会发送给服务器。
    public let instanceIdentifier: UUID

    /// 在原始请求、修改器和执行链之间共享的取消状态引用。
    public var isCancelledRef: NtkCancellableState?

    /// 最终发送给服务器的请求参数快照。
    ///
    /// 外部可以读取它来判断前序修改器已经生成了什么参数，但不能直接替换字典。写入必须使用
    /// `setParameter`、`mergeParameters` 或 `setParameters`，因为这些方法还会同步维护该字段
    /// 是否写入缓存键和去重键的规则。
    public private(set) var parameters: [String: Sendable]?

    /// 最终发送给服务器的 HTTP Header 快照。
    ///
    /// 外部可以读取它来复用前序修改器写入的 Header，但不能直接修改字典。写入必须使用
    /// `setHeader`、`mergeHeaders` 或 `setHeaders`，从而保证真实 Header 与对应的
    /// Request Identity 规则不会失去同步。
    public private(set) var headers: [String: String]?

    /// 当前执行实际使用的超时时间。
    ///
    /// 初始化时复制原始请求值，executor 随后会根据全局默认值解析出最终结果并写回。框架外部
    /// 只能读取，避免 Request Identity、请求去重和真实网络任务看到三个不同的超时时间。
    public internal(set) var timeout: TimeInterval

    /// 随请求快照传递的请求级附加数据。
    ///
    /// 它供业务代码和拦截器交换与网络 payload 无关的上下文，不会自动加入 Header、参数或
    /// Request Identity。它与 `NtkInterceptorContext.extraData` 属于不同阶段，框架不会在二者之间
    /// 自动同步或回写。
    public var extraData: [String: Sendable] = [:]

    /// 缓存键与请求去重键需要的本地附属状态。
    ///
    /// 这里不再把 Header 规则、参数规则和附加值作为三个散落属性暴露在主体结构中。统一容器
    /// 表明它们服务于同一件事：在不改变真实网络请求的前提下，描述 Request Identity 应如何生成。
    private var requestIdentityState = RequestIdentityState()

    /// 从原始请求创建可修改副本。
    ///
    /// Header 和参数复制后可以由请求修改器继续调整；其他接口定义仍由 `originalRequest` 提供。
    /// 每次初始化都会创建新的 `instanceIdentifier`，即使传入的是同一个原始请求对象也不复用。
    public init(_ request: iNtkRequest) {
        self.originalRequest = request
        self.instanceIdentifier = UUID()
        self.parameters = request.parameters
        self.headers = request.headers
        self.timeout = request.timeout
    }
}

// MARK: - 原始请求的只读接口定义

public extension NtkMutableRequest {

    /// 请求修改器不能更换服务地址，因此始终读取原始请求的值。
    var baseURL: URL? {
        originalRequest.baseURL
    }

    /// 请求修改器不能更换接口路径，因此始终读取原始请求的值。
    var path: String {
        originalRequest.path
    }

    /// 请求修改器不能更换 HTTP 方法，因此始终读取原始请求的值。
    var method: NtkHTTPMethod {
        originalRequest.method
    }

    /// 原始请求声明的响应缓存配置。
    ///
    /// `nil` 表示不读写缓存。该配置只决定缓存是否启用及缓存时长，不负责选择哪些请求字段
    /// 写入 Request Identity。
    var cacheConfiguration: NtkCacheConfiguration? {
        originalRequest.cacheConfiguration
    }

    /// 原始请求声明的 Request Identity 策略。
    ///
    /// `nil` 表示继承 executor 创建时冻结的全局策略；非 `nil` 会完整替换全局策略。字段写入
    /// 方法传入的 `.include` 或 `.exclude` 优先于这里的策略。
    var requestIdentityPolicy: NtkRequestIdentityPolicy? {
        originalRequest.requestIdentityPolicy
    }
}

// MARK: - Header 修改

public extension NtkMutableRequest {

    /// 添加或替换一个 Header。
    ///
    /// 当你只需要修改一个字段时使用本方法。Header 名称按 HTTP 规则忽略大小写：如果当前
    /// 已存在 `Authorization`，再写入 `authorization` 会先删除旧字段，最终只保留新名称和新值。
    /// Header 一定会发送给服务器；`requestIdentityRule` 只决定它是否参与缓存键和请求去重键。
    ///
    /// - Parameters:
    ///   - value: 要发送给服务器的 Header 值。
    ///   - field: HTTP Header 名称，例如 `Authorization`。
    ///   - requestIdentityRule: `.automatic` 继承全局或请求级策略；`.include` 强制写入 Request Identity；
    ///     `.exclude` 仍会发送 Header，但不把它写入 Request Identity。
    mutating func setHeader(
        _ value: String,
        forField field: String,
        requestIdentityRule: NtkRequestIdentityRule = .automatic
    ) {
        removeStoredHeaders(named: field)
        if headers == nil {
            headers = [:]
        }
        headers?[field] = value
        requestIdentityState.record(requestIdentityRule, forHeaderNamed: field)
    }

    /// 把多个 Header 合并到当前请求中，并保留未出现在 `newHeaders` 中的旧 Header。
    ///
    /// 当你只是追加一组公共 Header 时使用本方法；如果目标是用一份新字典完整替换旧 Header，
    /// 应使用 `setHeaders`。每个输入字段都按 `setHeader` 的大小写规则处理，并使用同一个
    /// `requestIdentityRule`。输入中存在大小写不同但 HTTP 语义同名的字段时，按字段名排序后最后
    /// 处理的值生效，使结果不依赖 Dictionary 的遍历顺序。
    ///
    /// - Parameters:
    ///   - newHeaders: 要合并进当前请求的 Header。
    ///   - requestIdentityRule: 应用于本次输入中每个 Header 的 Request Identity 规则。
    mutating func mergeHeaders(
        _ newHeaders: [String: String],
        requestIdentityRule: NtkRequestIdentityRule = .automatic
    ) {
        for field in newHeaders.keys.sorted() {
            if let value = newHeaders[field] {
                setHeader(value, forField: field, requestIdentityRule: requestIdentityRule)
            }
        }
    }

    /// 用 `newHeaders` 完整替换当前请求的全部 Header。
    ///
    /// 当调用方已经生成最终 Header 集合、不希望保留任何旧字段时使用本方法。执行后，旧 Header
    /// 及其 Request Identity 规则全部消失；新字段使用本次传入的统一规则。传入空字典会得到空 Header
    /// 字典，而 `removeAllHeaders()` 表示明确恢复为没有 Header 的 `nil` 状态。
    ///
    /// - Parameters:
    ///   - newHeaders: 替换后的完整 Header 集合。
    ///   - requestIdentityRule: 应用于全部新 Header 的 Request Identity 规则。
    mutating func setHeaders(
        _ newHeaders: [String: String],
        requestIdentityRule: NtkRequestIdentityRule = .automatic
    ) {
        headers = [:]
        requestIdentityState.removeAllHeaderRules()
        mergeHeaders(newHeaders, requestIdentityRule: requestIdentityRule)
    }

    /// 删除一个 Header 以及它对应的 Request Identity 规则。
    ///
    /// Header 名称按 HTTP 规则忽略大小写，因此传入 `authorization` 也会删除当前保存的
    /// `Authorization`。不存在的字段会被安全忽略；删除最后一个字段后保留空字典，只有调用
    /// `removeAllHeaders()` 才会把 Header 状态恢复为 `nil`。
    mutating func removeHeader(forField field: String) {
        removeStoredHeaders(named: field)
        requestIdentityState.removeRule(forHeaderNamed: field)
    }

    /// 删除全部 Header 及其 Request Identity 规则。
    ///
    /// 执行后 `headers` 为 `nil`，真实请求不再发送任何自定义 Header。参数和只在本地使用的
    /// 附加 Request Identity 值不受影响。
    mutating func removeAllHeaders() {
        headers = nil
        requestIdentityState.removeAllHeaderRules()
    }
}

// MARK: - 参数修改

public extension NtkMutableRequest {

    /// 添加或替换一个请求参数。
    ///
    /// 当你只需要修改一个参数时使用本方法。参数名属于业务协议并区分大小写，因此 `token` 和
    /// `Token` 是两个不同参数。参数一定会进入真实请求 payload；`requestIdentityRule` 只决定它
    /// 是否参与缓存键和请求去重键。
    ///
    /// - Parameters:
    ///   - value: 要写入真实请求 payload 的参数值。
    ///   - key: 参数名称。
    ///   - requestIdentityRule: `.automatic` 继承全局或请求级策略；`.include` 强制写入 Request Identity；
    ///     `.exclude` 仍会发送参数，但不把它写入 Request Identity。
    mutating func setParameter(
        _ value: Sendable,
        forKey key: String,
        requestIdentityRule: NtkRequestIdentityRule = .automatic
    ) {
        if parameters == nil {
            parameters = [:]
        }
        parameters?[key] = value
        requestIdentityState.record(requestIdentityRule, forParameterNamed: key)
    }

    /// 把多个参数合并到当前 payload 中，并保留未出现在 `newParameters` 中的旧参数。
    ///
    /// 当你只是追加一组公共参数时使用本方法；如果目标是用新字典完整替换旧 payload，应使用
    /// `setParameters`。输入字段按名称排序后逐个写入，使内部处理顺序稳定；所有输入字段使用
    /// 同一个 `requestIdentityRule`。
    ///
    /// - Parameters:
    ///   - newParameters: 要合并进当前请求的参数。
    ///   - requestIdentityRule: 应用于本次输入中每个参数的 Request Identity 规则。
    mutating func mergeParameters(
        _ newParameters: [String: Sendable],
        requestIdentityRule: NtkRequestIdentityRule = .automatic
    ) {
        for key in newParameters.keys.sorted() {
            if let value = newParameters[key] {
                setParameter(value, forKey: key, requestIdentityRule: requestIdentityRule)
            }
        }
    }

    /// 用 `newParameters` 完整替换当前请求的全部参数。
    ///
    /// 当调用方已经生成最终 payload、不希望保留任何旧参数时使用本方法。执行后，旧参数及其
    /// Request Identity 规则全部消失；新参数使用本次传入的统一规则。传入空字典会得到空参数字典，
    /// 而 `removeAllParameters()` 表示明确恢复为没有参数的 `nil` 状态。
    ///
    /// - Parameters:
    ///   - newParameters: 替换后的完整参数集合。
    ///   - requestIdentityRule: 应用于全部新参数的 Request Identity 规则。
    mutating func setParameters(
        _ newParameters: [String: Sendable],
        requestIdentityRule: NtkRequestIdentityRule = .automatic
    ) {
        parameters = newParameters
        requestIdentityState.removeAllParameterRules()
        for key in newParameters.keys.sorted() {
            requestIdentityState.record(requestIdentityRule, forParameterNamed: key)
        }
    }

    /// 删除一个请求参数以及它对应的 Request Identity 规则。
    ///
    /// 参数名称精确匹配且区分大小写。不存在的参数会被安全忽略；删除最后一个参数后保留空字典，
    /// 只有调用 `removeAllParameters()` 才会把参数状态恢复为 `nil`。
    mutating func removeParameter(forKey key: String) {
        parameters?.removeValue(forKey: key)
        requestIdentityState.removeRule(forParameterNamed: key)
    }

    /// 删除全部请求参数及其 Request Identity 规则。
    ///
    /// 执行后 `parameters` 为 `nil`，真实请求不再携带参数。Header 和只在本地使用的附加
    /// Request Identity 值不受影响。
    mutating func removeAllParameters() {
        parameters = nil
        requestIdentityState.removeAllParameterRules()
    }
}

// MARK: - 只影响本地 Request Identity 的附加值

public extension NtkMutableRequest {

    /// 指定一个“只用于区分本地缓存和请求去重结果”的值。
    ///
    /// 典型场景是用户资料接口：真实请求需要发送 `Authorization: Bearer <token>`，但 token 会
    /// 频繁刷新，不能据此判断是否是同一份用户资料。调用方会把这个 Header 标为 `.exclude`，
    /// 让 token 不参与 Request Identity；随后调用
    /// `setRequestIdentityValue(userID, forKey: "user")`。运行结果是服务器仍只收到 Authorization 和
    /// 参数，完全收不到 userID；框架生成缓存键和去重键时则额外记入 userID。因此同一用户换了
    /// token 仍可复用结果，不同用户即使访问相同 URL 也不会共享缓存或正在执行的请求。
    ///
    /// 这个方法不用于传递服务器需要的数据：服务器需要的数据应写入 Header 或参数。也不应用于
    /// token、时间戳、随机数等每次请求都会变化的值，否则同一资源会被拆成多个缓存和任务。
    /// 相同 `key` 再次写入会替换旧值；`key` 区分大小写。
    ///
    /// - Parameters:
    ///   - value: 用来区分缓存和请求去重结果的稳定业务值，例如当前 userID 或 tenantID。
    ///   - key: 该值在 Request Identity 中使用的业务名称，例如 `user` 或 `tenant`；它不是 Header
    ///     名称、参数名，也不会发送给服务器。
    mutating func setRequestIdentityValue(_ value: String, forKey key: String) {
        requestIdentityState.requestIdentityValues[key] = value
    }

    /// 删除一个用于区分本地缓存和请求去重结果的值。
    ///
    /// 删除不会改变 URL、Header 或参数，服务器也不会感知。只有当其他参与 Request Identity 的
    /// Header、参数或 `requestIdentityValues` 仍能区分用户/租户时才应删除。例如 Authorization 已被
    /// `.exclude` 且没有其他用户标识时，删除 `user` 会让两个用户对同一路径的请求得到相同
    /// Request Identity，可能读到彼此的缓存或等待彼此正在执行的请求。
    ///
    /// - Parameter key: 要删除的业务名称，例如 `user`；名称区分大小写。
    mutating func removeRequestIdentityValue(forKey key: String) {
        requestIdentityState.requestIdentityValues.removeValue(forKey: key)
    }
}

// MARK: - extraData 访问

public extension NtkMutableRequest {

    /// 读取或写入请求级附加数据。
    ///
    /// 下标只操作 `extraData`，不会创建请求参数，也不会影响 Request Identity。
    subscript(key: String) -> Sendable? {
        get {
            extraData[key]
        }
        set {
            extraData[key] = newValue
        }
    }
}

// MARK: - 框架内部读取与执行状态更新

extension NtkMutableRequest {

    /// Request Identity builder 读取的“只用于区分结果”的业务值快照。
    ///
    /// 这些值不会作为 HTTP Header、参数或 body 发送。builder 会把它们作为独立字段编码到
    /// Request Identity 中，使缓存和请求去重能够在动态 token 被排除后继续区分 userID、tenantID
    /// 等业务身份；独立编码也避免它们与同名 Header 或参数混在一起。
    internal var requestIdentityValues: [String: String] {
        requestIdentityState.requestIdentityValues
    }

    /// 返回某个 Header 最终采用的字段级 Request Identity 规则。
    ///
    /// Header 名称按 HTTP 语义忽略大小写；没有显式记录时返回 `.automatic`，由有效策略决定。
    internal func requestIdentityRuleForHeader(named name: String) -> NtkRequestIdentityRule {
        requestIdentityState.ruleForHeader(named: name)
    }

    /// 返回某个参数最终采用的字段级 Request Identity 规则。
    ///
    /// 参数名称精确匹配且区分大小写；没有显式记录时返回 `.automatic`，由有效策略决定。
    internal func requestIdentityRuleForParameter(named name: String) -> NtkRequestIdentityRule {
        requestIdentityState.ruleForParameter(named: name)
    }

    /// 在 executor 创建执行快照前重新读取原始请求的动态超时值。
    ///
    /// 读取发生在所有请求修改器执行之前，保证本次执行使用调用时的配置，而不是包装器初始化后
    /// 可能已经过期的值。
    internal mutating func refreshConfigurationSnapshot() {
        timeout = originalRequest.timeout
    }

    /// 保存 executor 解析后的最终超时时间。
    ///
    /// 后续网络任务和请求去重键都读取这个结果，避免各组件分别解析全局默认值而产生差异。
    internal mutating func applyEffectiveTimeout(_ value: TimeInterval) {
        timeout = value
    }
}

// MARK: - 私有存储操作

private extension NtkMutableRequest {

    /// 删除当前字典中与 `name` 大小写不同但 HTTP 语义相同的所有 Header。
    ///
    /// Swift Dictionary 把 `Authorization` 和 `authorization` 当成两个 key，而 HTTP 把它们
    /// 当成同一个字段。每次写入或删除前统一清除全部变体，可保证真实请求里最多保留一个同名
    /// Header，也避免 Request Identity builder 面对无法稳定选择的重复字段。
    mutating func removeStoredHeaders(named name: String) {
        let normalizedName = name.lowercased()
        let matchingNames = headers?.keys.filter {
            $0.lowercased() == normalizedName
        } ?? []
        for matchingName in matchingNames {
            headers?.removeValue(forKey: matchingName)
        }
    }
}

// MARK: - Request Identity 本地附属状态

/// 与真实网络 payload 同步维护、但绝不会发送给服务器的 Request Identity 状态。
///
/// Header 和参数规则只保存显式的 `.include` / `.exclude`；`.automatic` 通过删除记录表示，
/// 从而自然回到全局或请求级策略。`requestIdentityValues` 不对应真实请求字段：它们不会发送给
/// 服务器，只在构建缓存键和请求去重键时用于区分 user、tenant 等业务身份。
private struct RequestIdentityState: Sendable {

    /// 小写 Header 名称到显式规则的映射；小写存储用于实现 HTTP 大小写不敏感语义。
    var headerRules: [String: NtkRequestIdentityRule] = [:]

    /// 参数原始名称到显式规则的映射；不转换大小写，因为参数名称属于区分大小写的业务协议。
    var parameterRules: [String: NtkRequestIdentityRule] = [:]

    /// 不发送给服务器、只用于区分缓存和请求去重结果的业务值。
    ///
    /// 例如用户资料请求排除了会变化的 Authorization token 后，可保存
    /// `["user": "42"]`。网络层仍只发送 token；Request Identity builder 会额外编码 `user = 42`，
    /// 使用户 42 与用户 99 的缓存和正在执行的请求保持隔离。
    var requestIdentityValues: [String: String] = [:]

    /// 读取 Header 的显式规则；没有记录表示继续使用 `.automatic` 策略判断。
    func ruleForHeader(named name: String) -> NtkRequestIdentityRule {
        headerRules[name.lowercased()] ?? .automatic
    }

    /// 读取参数的显式规则；没有记录表示继续使用 `.automatic` 策略判断。
    func ruleForParameter(named name: String) -> NtkRequestIdentityRule {
        parameterRules[name] ?? .automatic
    }

    /// 记录一个 Header 的字段级规则。
    ///
    /// `.automatic` 不需要占用状态，删除旧记录即可恢复策略继承；另外两种值会覆盖该 Header
    /// 之前的规则。名称统一转成小写，使不同大小写写法指向同一个逻辑字段。
    mutating func record(_ rule: NtkRequestIdentityRule, forHeaderNamed name: String) {
        let normalizedName = name.lowercased()
        switch rule {
        case .automatic:
            headerRules.removeValue(forKey: normalizedName)
        case .include, .exclude:
            headerRules[normalizedName] = rule
        }
    }

    /// 记录一个参数的字段级规则。
    ///
    /// `.automatic` 删除旧记录并恢复策略继承；另外两种值覆盖该精确参数名之前的规则。
    mutating func record(_ rule: NtkRequestIdentityRule, forParameterNamed name: String) {
        switch rule {
        case .automatic:
            parameterRules.removeValue(forKey: name)
        case .include, .exclude:
            parameterRules[name] = rule
        }
    }

    /// 删除指定 Header 的显式规则，使以后同名字段不会继承已经删除字段的旧状态。
    mutating func removeRule(forHeaderNamed name: String) {
        headerRules.removeValue(forKey: name.lowercased())
    }

    /// 删除指定参数的显式规则，使以后同名字段不会继承已经删除参数的旧状态。
    mutating func removeRule(forParameterNamed name: String) {
        parameterRules.removeValue(forKey: name)
    }

    /// 清除全部 Header 规则；参数规则和本地附加值保持不变。
    mutating func removeAllHeaderRules() {
        headerRules.removeAll()
    }

    /// 清除全部参数规则；Header 规则和本地附加值保持不变。
    mutating func removeAllParameterRules() {
        parameterRules.removeAll()
    }
}

// MARK: - 调试输出

extension NtkMutableRequest: CustomStringConvertible {

    /// 输出真正参与执行的请求字段，便于调试修改器结果。
    ///
    /// Request Identity 规则和附加值可能包含业务隔离信息，因此这里刻意不输出它们。
    public var description: String {
        """
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
