import Foundation

/// `iNtkParsingHooks` 的统一分发器。
///
/// 该类型的唯一职责，是把 parsing 生命周期通知按既定事件分发给多个 hooks，
/// 并隔离 hook 自身异常，避免旁路副作用污染主解析流程。
///
/// 设计目的：
/// - 将 hook fan-out 逻辑从 parser / policy 中抽离，避免主流程出现散落的循环调用
/// - 把“hook 抛错仅记录、不改 outcome”的 contract 固化在单一位置
/// - 让 parser 与 policy 只表达“何时通知”，而不关心“如何安全通知多个 hook”
struct NtkParsingHookDispatcher: Sendable {
    /// 当前解析链路注入的 hooks 列表。
    ///
    /// 顺序即分发顺序；前一个 hook 失败不会阻止后一个 hook 收到同一事件。
    let hooks: [any iNtkParsingHooks]

    /// 创建一个用于当前 parser 实例的 hook 分发器。
    ///
    /// - Parameter hooks: 需要接收 parsing 生命周期通知的 hooks。默认空数组，表示当前链路没有旁路观察者。
    init(hooks: [any iNtkParsingHooks] = []) {
        self.hooks = hooks
    }

    /// 向所有 hooks 分发“header 已成功解释”通知。
    ///
    /// - Parameters:
    ///   - retCode: decoder 已解释出的业务返回码。
    ///   - msg: decoder 已解释出的业务消息文本。
    ///   - context: 当前请求的拦截器上下文。
    func didDecodeHeader(
        retCode: Int,
        msg: String?,
        context: NtkInterceptorContext
    ) async {
        await notify("didDecodeHeader") { hook in
            try await hook.didDecodeHeader(retCode: retCode, msg: msg, context: context)
        }
    }

    /// 向所有 hooks 分发“即将开始业务成功判定”通知。
    ///
    /// - Parameters:
    ///   - response: policy 正在评估的候选响应。
    ///   - context: 当前请求的拦截器上下文。
    func willValidate(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("willValidate") { hook in
            try await hook.willValidate(response, context: context)
        }
    }

    /// 向所有 hooks 分发“业务成功判定失败”通知。
    ///
    /// - Parameters:
    ///   - response: 已被判定为业务失败的响应对象。
    ///   - context: 当前请求的拦截器上下文。
    func didValidateFail(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("didValidateFail") { hook in
            try await hook.didValidateFail(response, context: context)
        }
    }

    /// 向所有 hooks 分发“解析成功完成”通知。
    ///
    /// - Parameters:
    ///   - response: 已形成最终成功结果的响应对象。
    ///   - context: 当前请求的拦截器上下文。
    func didComplete(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("didComplete") { hook in
            try await hook.didComplete(response, context: context)
        }
    }

    /// 以逐个隔离的方式向 hooks 分发某个生命周期事件。
    ///
    /// - Parameters:
    ///   - event: 事件名称，仅用于日志标识，便于定位是哪一个生命周期节点发生了 hook 异常。
    ///   - invocation: 对单个 hook 的调用逻辑。dispatcher 只负责调用与隔离，不负责解释该事件的业务含义。
    /// - Note: 任意单个 hook 抛错只会被记录并忽略；分发器会继续通知剩余 hooks。
    private func notify(
        _ event: String,
        invocation: @Sendable (any iNtkParsingHooks) async throws -> Void
    ) async {
        for hook in hooks {
            do {
                try await invocation(hook)
            } catch {
                logger.warning(
                    "[NtkParsingHookDispatcher] Hook \(event) 失败并已忽略: \(error)",
                    category: .network
                )
            }
        }
    }
}
