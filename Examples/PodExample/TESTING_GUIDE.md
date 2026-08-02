# CooNetwork Pod 集成测试指南

本工程通过两层测试验证 CooNetwork 的 CocoaPods 集成：

- `PodExampleTests`：不依赖公网的自动化 XCTest，验证公开 API 契约。
- `PodExample` 应用：访问 JSONPlaceholder 和 HTTPBin 的真实网络冒烟测试。

## 环境要求

- Xcode 16.3 或更高版本
- CocoaPods 1.16 或更高版本
- iOS 15.0 或更高版本的模拟器
- 运行应用内测试时需要能够访问 `jsonplaceholder.typicode.com` 和 `httpbin.org`

## 安装 Pods

在 `Examples/PodExample` 目录运行：

```bash
pod install
```

本地 Pod 使用仓库根目录源码。网络库增删源码文件后必须重新执行该命令，以刷新 `Pods.xcodeproj` 的文件列表。

## 自动化测试

在 `Examples/PodExample` 目录运行：

```bash
xcodebuild test \
  -workspace PodExample.xcworkspace \
  -scheme PodExample \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PodExampleTests
```

`PodExampleTests` 只导入公开的 `CooNetwork` 模块，不使用 `@testable import`。当前覆盖：

1. 请求修改器在客户端执行前修改参数、请求头和 request extraData。
2. 同优先级请求修改器保持注册顺序。
3. 请求修改器抛错后不会继续执行客户端。
4. context extraData 通过上下文副本向下游传播。
5. 解析 hooks 收到修改后的请求快照和上下文快照。
6. 缓存读取和网络请求分别从初始请求构建独立快照。
7. 多个独立网络请求无需全局 Actor 即可并发执行。

## 应用内测试

打开 `PodExample.xcworkspace`，选择 `PodExample` Scheme 和 iOS 模拟器后运行应用。

- 快速验证：运行 T1-T4。
- 全面测试：按顺序运行 T1-T11。
- 单项测试：点击对应编号按钮。
- 清理：取消当前任务并清空结果。

### 测试项

| 编号 | 内容 | 主要证据 |
|------|------|----------|
| T1 | 基础请求 | JSONPlaceholder 返回指定 Post |
| T2 | 类型化响应 | `NtkAF<Post>` 返回 `Post` 数据 |
| T3 | 日志链路 | HTTPBin 请求完成并产生网络日志 |
| T4 | 相同请求并发 | 5 个相同请求均成功且结果一致 |
| T5 | 缓存标记观察 | 连续响应的 `isCache` 状态和数据一致性 |
| T6 | HTTPBin 可用性 | HTTPBin GET 请求成功 |
| T7 | 独立请求并发 | 10 个不同请求返回 10 个唯一 ID |
| T8 | 取消与内存观察 | 取消 50 个延迟任务后的内存变化 |
| T9 | 请求修改 | HTTPBin 回显修改后的参数和请求头 |
| T10 | 修改器顺序 | 回显头为 `first,second` |
| T11 | 上下文值流 | 上游为空，下游读取到 `propagated` |

## 判定标准

- `PodExampleTests` 全部通过。
- `PodExample` 可以针对 iOS Simulator 构建。
- T9-T11 在网络可用时通过。
- 公网不可达只影响应用内冒烟测试，不应影响自动化 XCTest。
- 测试报告不得把“响应一致”表述成“已证明只发起一次请求”，也不得把普通成功请求表述成“已验证重试”。
