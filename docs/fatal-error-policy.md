# fatalError 使用策略（精简）

## 原则
- 仅用于开发期契约错误（Programmer Error）。
- 运行期可恢复异常一律 `throw`。
- 判断标准：无法恢复 + 状态不可信 + 属于内部强约束，才可 `fatalError`。

## 禁止 fatalError
- 网络波动、超时、服务端失败、解码失败。
- 外部输入或数据质量问题。
- 能通过错误返回让上层处理的场景。

## 当前保留项
- `AFClient.execute`：请求类型必须是 `iAFRequest`。
- `AFDataParsingInterceptor`：请求类型必须是 `iAFRequest`。
- `iNtkClient.cancel` 默认实现：禁止误用。

## 新增准入
- PR 必须写明：契约定义、为何不能 `throw`、失败后状态影响。
- 需要最小复现或测试证明属于编程期错误。
- 默认先按 `throw` 设计，满足全部条件再升级为 `fatalError`。
