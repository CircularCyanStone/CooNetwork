import Foundation

struct NtkParsingHookDispatcher: Sendable {
    let hooks: [any iNtkParsingHooks]

    init(hooks: [any iNtkParsingHooks] = []) {
        self.hooks = hooks
    }

    func didDecodeHeader(
        retCode: Int,
        msg: String?,
        context: NtkInterceptorContext
    ) async {
        await notify("didDecodeHeader") { hook in
            try await hook.didDecodeHeader(retCode: retCode, msg: msg, context: context)
        }
    }

    func willValidate(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("willValidate") { hook in
            try await hook.willValidate(response, context: context)
        }
    }

    func didValidateFail(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("didValidateFail") { hook in
            try await hook.didValidateFail(response, context: context)
        }
    }

    func didComplete(
        _ response: any iNtkResponse,
        context: NtkInterceptorContext
    ) async {
        await notify("didComplete") { hook in
            try await hook.didComplete(response, context: context)
        }
    }

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
