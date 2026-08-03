# Request Key 命名重构设计

## 背景

现有模块使用 `Identity`、`Participation`、`Canonical` 等词描述缓存与请求去重共用的请求 key。
这些名称偏向实现术语，调用方无法从 `headerIdentityParticipation`、`NtkRequestIdentity` 等符号
直接判断它们与缓存 key、并发请求合并之间的关系。

本次只调整命名和文件组织，不改变字段筛选、稳定编码、缓存、去重、超时或失败降级行为。

## 词汇选择

考虑过三组核心词：

1. `RequestKey`：直接对应缓存 key 与去重基础 key，日常开发含义最明确。
2. `RequestFingerprint`：能表达内容指纹，但名称长，调用处噪声较大。
3. `RequestSignature`：容易与接口签名和鉴权签名混淆。

采用 `RequestKey`。旧接口不保留 deprecated 或 typealias 兼容层，避免旧词继续出现在自动补全中。

## 公开接口命名

| 旧名称 | 新名称 | 调用方应理解的含义 |
| --- | --- | --- |
| `NtkIdentityParticipation` | `NtkRequestKeyRule` | 单个 Header/参数是否写入请求 key |
| `.included` | `.include` | 强制把字段写入请求 key |
| `.excluded` | `.exclude` | 字段仍发送，但不写入请求 key |
| `identity:` | `requestKeyRule:` | 本次字段写入使用的 key 规则 |
| `NtkRequestIdentityPolicy` | `NtkRequestKeyPolicy` | automatic 字段的全局或请求级 key 规则 |
| `normalizeHeaders` | `transformHeaders` | 在写入 key 前转换 automatic Header |
| `normalizeParameters` | `transformParameters` | 在写入 key 前转换 automatic 参数 |
| `addIdentityComponent` | `addRequestKeyValue` | 加入不发送到服务器的稳定 key/value |
| `removeIdentityComponent` | `removeRequestKeyValue` | 删除本地附加 key/value |
| `NtkRequestIdentity` | `NtkRequestKey` | 已生成、可供缓存使用的不透明稳定 key |
| `digest` | `value` | 传给缓存存储的版本化字符串值 |

推荐调用形式：

```swift
request.addHeader(
    key: "Authorization",
    value: "Bearer \(token)",
    requestKeyRule: .exclude
)
request.addParameter(
    key: "timestamp",
    value: timestamp,
    requestKeyRule: .exclude
)
request.addRequestKeyValue(key: "user", value: userID)
```

## 内部实现命名

| 旧名称 | 新名称 |
| --- | --- |
| `identity/` | `requestKey/` |
| `NtkRequestIdentityBuilder` | `NtkRequestKeyBuilder` |
| `NtkCanonicalIdentityEncoder` | `NtkRequestKeyEncoder` |
| `NtkRequestIdentityBuilder.Failure` | `NtkRequestKeyBuilder.BuildError` |
| `diagnosticDescription` | `logMessage` |
| `projectHeaders` | `headersForRequestKey` |
| `projectParameters` | `parametersForRequestKey` |
| `headerIdentityParticipation` | `headerRequestKeyRules` |
| `parameterIdentityParticipation` | `parameterRequestKeyRules` |
| `storedIdentityComponents` | `storedRequestKeyValues` |
| `identityComponents` | `requestKeyValues` |
| `identityParticipation(forHeader:)` | `requestKeyRule(forHeader:)` |
| `identityParticipation(forParameter:)` | `requestKeyRule(forParameter:)` |
| `setHeaderParticipation` | `setHeaderRequestKeyRule` |
| `setParameterParticipation` | `setParameterRequestKeyRule` |
| `pruneIdentityMetadata` | `removeStaleRequestKeyRules` |
| `NtkDeduplicationIdentity` | `NtkDeduplicationKey` |
| `requestIdentity` | `requestKey` |
| `deduplicationIdentity` | `deduplicationKey` |

`NtkEffectiveTimeoutResolver` 不负责请求 key，移出 `requestKey/`，放入 `deduplication/` 并重命名为
`NtkRequestTimeoutResolver`。它仍负责为实际 timeout task 和 deduplication key 提供同一个有效超时。

## 文件布局

```text
NtkNetwork/
  requestKey/
    NtkRequestKeyRule.swift
    NtkRequestKeyPolicy.swift
    NtkRequestKey.swift
    NtkRequestKeyBuilder.swift
    NtkRequestKeyBuilder+BuildError.swift
    NtkRequestKeyEncoder.swift

  deduplication/
    NtkRequestTimeoutResolver.swift
    NtkDeduplicationKey.swift
```

## 接入与出口

接入点保持在 `NtkNetworkExecutor.makeContext()`：请求修改器执行完毕后，executor 调用
`NtkRequestKeyBuilder.build()`，把结果写入 `NtkInterceptorContext.requestKey`。

缓存出口直接使用 `requestKey.value` 访问 `iNtkCacheStorage`。去重出口把 request key、响应类型、
有效超时和 namespace 组成 `NtkDeduplicationKey`，再作为 `NtkTaskManager.RuntimeKey.shared` 的值。

## 错误与运行行为

本次不改变运行行为：不支持的参数类型、非有限数值、转换闭包抛错、Header 冲突等仍产生内部
`BuildError`。executor 记录脱敏日志，把 request key 置为 nil，跳过缓存和共享执行，网络请求及
框架超时继续。

## 完成标准

- 生产源码、测试、README 和当前架构文档统一使用 `RequestKey` 词汇。
- Swift 文件名、类型名、参数标签、属性名和方法名不存在旧 `IdentityParticipation` 接口。
- `identity/` 目录删除，timeout resolver 归入去重模块。
- 不添加旧名称兼容层。
- Git diff 中除命名、注释和文件移动外不存在逻辑变化。
- 按用户要求不执行 `swift test`。
