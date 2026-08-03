# 请求级去重覆盖设计

## 目标

支持将全局去重设为默认关闭，并仅为指定请求显式开启；同时保留全局开启时按请求关闭去重的能力。

## 公开接口

新增 `NtkDeduplicationPolicy`：

```swift
public enum NtkDeduplicationPolicy: Sendable {
    case inherit
    case enabled
    case disabled
}
```

`NtkMutableRequest` 默认使用 `.inherit`。提供 `enableDeduplication()` 与既有的
`disableDeduplication()`，分别写入 `.enabled` 和 `.disabled`。未调用任一方法时，请求继承
`NtkConfiguration.Builder.isDeduplicationEnabled`。

## 解析规则

`NtkNetworkExecutor` 在请求修改器执行后解析最终请求策略：

| 请求策略 | 全局值 | 本次去重值 |
| --- | --- | --- |
| `.inherit` | `false` | `false` |
| `.inherit` | `true` | `true` |
| `.enabled` | 任意 | `true` |
| `.disabled` | 任意 | `false` |

`includeDeduplication` 保留为执行器内部限制：它为 `false` 时，无论上述结果为何均不构建去重键。
普通 `execute()` 传入 `true`；缓存读取等非网络执行路径传入 `false`。

## 兼容性和测试

全局和请求均未配置时维持现有默认行为：全局默认 `true`，请求继承后启用去重。既有
`disableDeduplication()` 保持可用，语义升级为请求级强制关闭。

在 `NtkNetworkExecutorTests` 中测试策略解析结果：默认继承、全局关闭后的显式开启、全局开启后的显式关闭，以及 `includeDeduplication == false` 的优先级。测试通过观察 executor context 的
`deduplicationKey` 是否存在，不依赖内部实现细节。
