# 网络执行可观测性设计

## 背景

`NtkLogger` 目前先以 `isLoggingEnabled` 完全屏蔽日志，再以初始化时固定的 `.info` 作为最低等级。因此关闭开关时 `warning`、`error` 和 `fault` 也不可见；开启开关后 `debug` 仍不可见。这与开发期需要完整诊断、运行期仍需暴露框架降级和失败信号的目标不一致。

请求身份和去重在最近重构后已具备稳定的执行边界：executor 在请求修改完成后构建一次 `NtkRequestIdentity`，再派生 `NtkDeduplicationKey`；`NtkTaskManager` 决定复用、新建、取消及清理任务。当前这些关键决策缺少完整、可关联的日志。

## 目标

- 开启 `isLoggingEnabled` 时，输出从 `.debug` 到 `.fault` 的全部框架日志。
- 关闭 `isLoggingEnabled` 时，仍输出 `.warning`、`.error` 和 `.fault`，保留降级与失败信号。
- 为请求身份、去重、超时、缓存和请求执行的关键决策提供可关联的结构化消息。
- 日志不改变请求、缓存、去重、超时、取消或错误传播语义。
- 不输出 Header、参数、请求体、身份组成值、token、签名或任意不受框架控制的错误详情。

## 非目标

- 不新增业务埋点、远程日志上传或持久化策略。
- 不让日志等级成为新的公开配置接口；本次沿用现有 `isLoggingEnabled`。
- 不将缓存未命中、去重未命中、正常取消等预期分支标记为 warning。

## 日志等级策略

`NtkLogger` 的有效最低等级动态从配置读取：

| `isLoggingEnabled` | 最低等级 | 语义 |
| --- | --- | --- |
| `true` | `.debug` | 详细诊断模式，输出全部等级。 |
| `false` | `.warning` | 常规模式，仅保留可行动的降级、失败和框架故障。 |

这使该布尔值的语义成为“是否启用详细框架诊断”。相关 API 注释必须同步更新。等级判断在每次记录日志时读取配置，不得在 `NtkLogger.shared` 初始化时冻结，以支持应用运行期更新 `NtkConfiguration`。

## 关键节点

所有消息以稳定事件名开头，并在可用时带上 `requestID`（请求实例 UUID）和 `identity`（`NtkRequestIdentity.value`）。`identity` 是版本化哈希键，可作为本地关联标识；不得用它反推或输出原始参与字段。

| 模块 | 事件 | 等级 | 内容 |
| --- | --- | --- | --- |
| executor | 请求修改完成、有效超时已解析 | debug | `requestID`、HTTP method、path、有效超时、缓存/去重是否参与。 |
| request identity | 构建成功 | debug | `requestID`、`identity`。 |
| request identity | 构建跳过 | debug | 缓存和去重均未参与时的原因。 |
| request identity | 构建失败并降级 | warning | `requestID`、脱敏的 `BuildError.logMessage`、缓存/去重已关闭。 |
| deduplication | 生成或未生成去重键 | debug | `requestID`、`identity`、有效超时、namespace；不得打印响应类型的字符串描述。 |
| task manager | 新建 owner、命中共享任务、follower 加入/离开、任务清理、取消 | debug | `requestID`、`identity`（共享时）和生命周期结果；隔离任务仅记录 `requestID`。 |
| task manager | 超时或底层任务失败 | error | `requestID`、`identity`（可用时）、错误类型和超时值；不拼接任意错误描述。 |
| cache | 读写命中、未命中、写入成功/失败、因无 identity 跳过 | debug | `requestID`、`identity`、结果。 |
| retry | 计划重试、重试成功、重试耗尽 | debug/error | 保留重试次数和延迟；错误只记录类型。 |
| interceptor chain / client | 请求开始、响应完成、最终失败 | debug/error | `requestID`、method、path、缓存标记、错误类型。 |

`warning` 只用于功能成功降级但需要开发者处理的情况，例如 request identity 不能构建而导致缓存与去重失效。正常缓存未命中、去重未命中、调用方取消和不启用缓存/去重均不是 warning。

## 错误与脱敏

- 框架自有的、已脱敏错误可以使用其专用日志文本，例如 `BuildError.logMessage`。
- 对 client、hook、解析器或业务闭包抛出的任意 `Error`，只记录 `String(reflecting: type(of: error))`，不记录 `localizedDescription`、`String(describing: error)` 或响应 payload。
- method 和 path 可用于定位路由；base URL、Header、参数、body、`requestIdentityValues` 和完整请求对象不得进入新增日志。
- 每个失败日志只在其语义拥有者处写一次，避免 executor、拦截器和任务管理器对同一失败重复报错。

## 测试

- 为 logger 增加可注入的输出观察点或等价测试边界，验证关闭详细日志时 `.debug`/`.info` 被过滤而 `.warning`/`.error`/`.fault` 保留；开启时全部保留。
- 覆盖 request identity 成功、跳过和失败降级的事件与等级。
- 覆盖去重新建、命中、follower 取消及 owner 清理的事件与等级。
- 对代表性日志断言禁止出现 token、参数值、身份组成值和原始错误描述。
- 运行完整 `swift test`，确保日志增加不改变已有去重、超时和请求身份行为。

## 验收标准

1. 仅配置 `isLoggingEnabled = true` 即可看到 `debug` 日志。
2. 配置为 `false` 时，开发者仍能看到框架的 warning、error 和 fault。
3. 一次可去重请求可从日志关联请求身份、去重决策、任务生命周期和最终结果。
4. 日志文本不含敏感请求内容或非框架控制的错误文本。
5. 全部现有测试和新增等级/脱敏测试通过。
