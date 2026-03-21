# I-5: 核心路径测试覆盖设计

## 背景

架构评审 I-5 指出缺少以下核心路径的测试：
- NtkInterceptorChainManager 链式执行
- NtkNetworkExecutor execute/loadCache 流程
- NtkNetwork.request()/requestWithCache() 端到端流程
- AFDataParsingInterceptor 各种解析路径

## 策略

方案 B：各文件独立 mock，不动现有代码，与现有测试风格一致。

## 文件清单

| 文件 | 测试目标 |
|------|----------|
| `NtkInterceptorChainManagerTests.swift` | 拦截器链执行顺序、短路、错误传播、context 传递 |
| `NtkNetworkExecutorTests.swift` | execute/loadCache/hasCacheData 各路径 |
| `NtkNetworkIntegrationTests.swift` | NtkNetwork.request()/requestWithCache() 端到端 |
| `AFDataParsingInterceptorTests.swift` | NtkNever/常规模型/nil data/空响应/解码失败 |

## 测试用例

### NtkInterceptorChainManagerTests

1. 空链直达 finalHandler
2. 单拦截器执行并传递到 finalHandler
3. 多拦截器按数组顺序执行（请求流顺序，响应流反向）
4. 拦截器短路（不调用 next），finalHandler 不被调用
5. 拦截器抛错，错误传播到调用方
6. 前一个拦截器修改 context.mutableRequest，后续拦截器可见

### NtkNetworkExecutorTests

1. execute() 成功：MockClient → ParsingInterceptor → NtkResponse
2. execute() 客户端抛错透传
3. execute() 拦截器按优先级统一排序
4. loadCache() 有缓存数据
5. loadCache() 无缓存返回 nil
6. loadCache() 无 cacheableClient 返回 nil
7. hasCacheData() 返回 true/false

### NtkNetworkIntegrationTests

1. request() 完整成功流程
2. request() 自定义拦截器被执行
3. requestWithCache() 缓存优先返回两个结果
4. requestWithCache() 无缓存只有网络结果
5. requestWithCache() 网络先返回则跳过缓存
6. cancel() 传播 isCancelled 状态

### AFDataParsingInterceptorTests

1. NtkNever 类型正常返回
2. 常规 Decodable 模型解析
3. data 为 nil + validation 通过 → serviceDataEmpty
4. data 为 nil + validation 失败 → validation 错误
5. 空响应体 → responseBodyEmpty
6. JSON 解码失败 → decodeInvalid
7. 已是目标类型直接返回

## Mock 策略

每个测试文件自带 private mock，不共享，不影响现有测试。
