# 设计决策记录

经评审确认的刻意设计。code review 时请勿将以下设计作为问题提出。

## 并发安全

- **NtkNetwork 使用 `@unchecked Sendable`** — 避免 Actor 传染性，配置层需在任意线程初始化且支持链式调用，内部通过 `lock.withLock` 保护可变状态，执行委托给 Actor
- **NtkUnfairLock 使用 `@unchecked Sendable`** — `os_unfair_lock` 是 C 类型，封装后通过锁保护内部状态，`@unchecked Sendable` 是唯一可行方案
- **NtkMutableRequest struct 拷贝不会状态不一致** — 拦截器只读访问，修改需显式赋值回 context，`@NtkActor` 保证串行执行

## 类型安全

- **NtkReturnCode.encode 使用 `try?`** — 防御性设计，`_type`/`rawValue` 由同一 init 设置不会不一致，生产环境不崩溃优先于严格错误传播
- **NtkDynamicData 中的 `as! T`** — switch type 已约束 T 的类型，不存在失败路径；rawValue/valueType 私有存储，构造方法同步设置
- **AFDataParsingInterceptor 的 `NtkNever() as! ResponseData`** — 前置 `is NtkNever.Type` 检查已确认类型，Swift 泛型不支持类型精化，`as!` 是标准做法

## 架构模式

- **AFClient 依赖 Alamofire 类型** — 适配器模式的正确应用，`iNtkClient` 协议是抽象层，AFClient 负责翻译为具体调用，再加一层才是过度抽象
- **NtkError.AF 嵌套枚举** — Swift enum 无法在 extension 中加 case，嵌套枚举让每个 client 有独立错误空间，是多来源错误的标准模式
- **NtkNetworkExecutor 三个方法的拦截器链构建"重复"** — 组合策略和错误处理完全不同，仅排序逻辑重复（已提取为 `sortInterceptors`），强行统一降低可读性

## 其他

- **缓存过期用时间戳比较** — `timeIntervalSince1970` 是 UTC 秒数，与时区无关，性能优于创建 Date 对象
- **NtkLogger 日志级别** — `log()` 方法已实现级别检查，所有便捷方法均经过检查，无绕过调用
- **NtkCacheMeta 用 NSSecureCoding 不用 Codable** — 设计定位为接口缓存，NSSecureCoding 满足 OC 组件存储需求，Codable 非核心需求
