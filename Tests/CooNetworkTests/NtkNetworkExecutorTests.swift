import Testing
import Foundation
@testable import CooNetwork

struct NtkNetworkExecutorTests {

    // MARK: - execute() 成功

    @Test
    func executeReturnsResponseOnSuccess() async throws {
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.execute()
        #expect(response.data == true)
        #expect(response.isCache == false)
    }

    // MARK: - execute() 客户端抛错透传

    @Test
    func executePropagatesclientError() async throws {
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/error-test"))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .failure(NtkError.requestTimeout(.framework(timeout: 30)))),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor())]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)
        do {
            _ = try await executor.execute()
            Issue.record("期望抛出错误")
        } catch {
            #expect(error is NtkError)
        }
    }

    // MARK: - execute() 拦截器按优先级排序

    @Test
    func executeSortsAllInterceptorsByPriority() async throws {
        let counter = ExecCallCounter()
        let lowPriority = ExecPriorityRecordingInterceptor(id: "low", prio: .low, counter: counter)
        let highPriority = ExecPriorityRecordingInterceptor(id: "high", prio: .high, counter: counter)

        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/priority-order"))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor()), lowPriority, highPriority]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)
        _ = try await executor.execute()
        let log = await counter.log()
        // high 优先级先执行
        #expect(log.first == "high")
    }

    @Test
    func executeDoesNotTreatOrdinaryInterceptorAsRequestModifier() async throws {
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/lookalike-modifier"))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecLookalikeRequestInterceptor()
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try await executor.execute()

        #expect(response.request.headers?["X-Lookalike-Modifier"] == nil)
    }

    @Test
    func executeAllowsRequestModifierToAlsoInterceptResponse() async throws {
        let counter = ExecCallCounter()
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/combined-modifier"))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecCombinedRequestInterceptor(counter: counter)
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try await executor.execute()

        #expect(response.request.headers?["X-Combined"] == "modified")
        #expect(await counter.log() == ["intercept"])
    }

    @Test
    func executeModifiesRequestInInterceptorPriorityOrder() async throws {
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/modifier-order"))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecAppendingRequestInterceptor(id: "low", prio: .low),
                ExecAppendingRequestInterceptor(id: "high", prio: .high)
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try await executor.execute()

        #expect(response.request.headers?["X-Modifier-Order"] == "high,low")
    }

    @Test
    func equalPriorityRequestModifiersKeepRegistrationOrder() async throws {
        var request = NtkMutableRequest(
            ExecDummyRequest(path: "/executor/equal-modifier-order")
        )
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecAppendingRequestInterceptor(id: "first", prio: .medium),
                ExecAppendingRequestInterceptor(id: "second", prio: .medium),
                ExecAppendingRequestInterceptor(id: "third", prio: .medium)
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try await executor.execute()

        #expect(response.request.headers?["X-Modifier-Order"] == "first,second,third")
    }

    @Test
    func executeAndLoadCacheBuildIndependentRequestsFromInitialSnapshot() async throws {
        let storage = ExecMockCacheStorage(cacheData: true, hasCacheResult: true)
        var request = NtkMutableRequest(ExecDummyRequest(
            path: "/executor/independent-requests",
            cacheConfiguration: .default()
        ))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(storage: storage),
                ExecIncrementingRequestInterceptor()
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        async let networkResponse = executor.execute()
        async let cacheResponse = executor.loadCache()
        let (network, cache) = try await (networkResponse, cacheResponse)

        #expect(network.request.headers?["X-Execution-Count"] == "1")
        #expect(cache?.request.headers?["X-Execution-Count"] == "1")
    }

    @Test
    func executeThrowsTypeMismatchForFinalTypedCastFailure() async {
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/type-mismatch"))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(ExecPassThroughParser())]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        do {
            _ = try await executor.execute()
            Issue.record("期望抛出最终 typed response cast 错误")
        } catch let error as NtkError {
            if case NtkError.invalidTypedResponse = error {
                #expect(Bool(true))
            } else {
                Issue.record("错误类型不符: \(error)")
            }
        } catch {
            Issue.record("抛出了未知错误类型: \(error)")
        }
    }

    // MARK: - loadCache() 有缓存

    @Test
    func loadCacheReturnsCachedResponse() async throws {
        let storage = ExecMockCacheStorage(cacheData: true, hasCacheResult: false)
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            cacheInterceptor: NtkCacheInterceptor(storage: storage),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.loadCache()
        #expect(response != nil)
        #expect(response?.isCache == true)
    }

    @Test
    func loadCacheWithRealParserStillReturnsTypedCachedResponse() async throws {
        let storage = ExecMockCacheStorage(
            cacheData: try JSONSerialization.data(withJSONObject: [
                "retCode": 0,
                "data": true,
                "retMsg": "ok"
            ]),
            hasCacheResult: false
        )

        var request = NtkMutableRequest(ExecDummyRequest(cacheConfiguration: .default()))

        let parser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(validation: ExecDummyValidation())
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(parser), NtkCacheInterceptor(storage: storage)]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try await executor.loadCache()
        #expect(response?.data == true)
        #expect(response?.isCache == true)
    }

    @Test
    func loadCacheWithRealParserAndThrowingHookStillReturnsTypedCachedResponse() async throws {
        let cachePayload = try JSONSerialization.data(withJSONObject: [
            "retCode": 0,
            "data": true,
            "retMsg": "ok"
        ])
        let baselineStorage = ExecMockCacheStorage(cacheData: cachePayload, hasCacheResult: false)
        let hookedStorage = ExecMockCacheStorage(cacheData: cachePayload, hasCacheResult: false)
        let hook = ExecThrowingHook()

        var baselineRequest = NtkMutableRequest(ExecDummyRequest(
            path: "/executor/cache-baseline",
            cacheConfiguration: .default()
        ))
        let baselineParser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(validation: ExecDummyValidation())
        let baselineConfig = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: baselineRequest,
            interceptors: [NtkResponseParserBox(baselineParser), NtkCacheInterceptor(storage: baselineStorage)]
        )
        let baselineExecutor = NtkNetworkExecutor<Bool>(config: baselineConfig)

        var hookedRequest = NtkMutableRequest(ExecDummyRequest(
            path: "/executor/cache-hook",
            cacheConfiguration: .default()
        ))
        let hookedParser = NtkDataParsingInterceptor<Bool, ExecTestKeys>(
            validation: ExecDummyValidation(),
            hooks: [hook]
        )
        let hookedConfig = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: hookedRequest,
            interceptors: [NtkResponseParserBox(hookedParser), NtkCacheInterceptor(storage: hookedStorage)]
        )
        let hookedExecutor = NtkNetworkExecutor<Bool>(config: hookedConfig)

        let baselineResponse = try #require(await baselineExecutor.loadCache())
        let hookedResponse = try #require(await hookedExecutor.loadCache())
        #expect(hookedResponse.data == baselineResponse.data)
        #expect(hookedResponse.code.intValue == baselineResponse.code.intValue)
        #expect(hookedResponse.code.stringValue == baselineResponse.code.stringValue)
        #expect(hookedResponse.msg == baselineResponse.msg)
        #expect(hookedResponse.isCache == baselineResponse.isCache)
        #expect(hookedResponse.msg == "ok")
        #expect(hook.events == ["didDecodeHeader", "willValidate", "didComplete"])
    }

    @Test
    func loadCacheAppliesInterceptorRequestModification() async throws {
        let storage = ExecMockCacheStorage(cacheData: true, hasCacheResult: false)
        var request = NtkMutableRequest(ExecDummyRequest(
            path: "/executor/cache-modifier",
            cacheConfiguration: .default()
        ))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(storage: storage),
                ExecStableRequestInterceptor()
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let response = try #require(await executor.loadCache())

        #expect(response.request.headers?["X-Stable-Parameter"] == "stable")
    }

    // MARK: - loadCache() 无缓存返回 nil

    @Test
    func loadCacheReturnsNilWhenNoCache() async throws {
        let storage = ExecMockCacheStorage(cacheData: nil, hasCacheResult: false)
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            cacheInterceptor: NtkCacheInterceptor(storage: storage),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.loadCache()
        #expect(response == nil)
    }

    // MARK: - loadCache() 无 cacheStorage 返回 nil

    @Test
    func loadCacheReturnsNilWithoutCacheStorage() async throws {
        let executor = makeExecutor(
            client: ExecMockClient(result: .success(())),
            parsingInterceptor: ExecMockParsingInterceptor()
        )
        let response = try await executor.loadCache()
        #expect(response == nil)
    }

    // MARK: - hasCacheData()

    @Test
    func hasCacheDataReturnsTrueWhenCacheExists() async throws {
        let storage = ExecMockCacheStorage(cacheData: nil, hasCacheResult: true)
        let executor = makeBoolExecutor(
            client: ExecMockClient(result: .success(())),
            cacheInterceptor: NtkCacheInterceptor(storage: storage)
        )
        let result = await executor.hasCacheData()
        #expect(result == true)
    }

    @Test
    func hasCacheDataReturnsFalseWithoutCacheStorage() async throws {
        let executor = makeBoolExecutor(
            client: ExecMockClient(result: .success(()))
        )
        let result = await executor.hasCacheData()
        #expect(result == false)
    }

    @Test
    func hasCacheDataAppliesInterceptorRequestModification() async throws {
        let capture = ExecCacheRequestCapture()
        let storage = ExecCapturingCacheStorage(capture: capture)
        var request = NtkMutableRequest(ExecDummyRequest(
            path: "/executor/has-cache-modifier",
            cacheConfiguration: .default()
        ))
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(storage: storage),
                ExecStableRequestInterceptor()
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let result = await executor.hasCacheData()

        #expect(result == true)
        #expect(await capture.headerValue(for: "X-Stable-Parameter") == "stable")
    }

    @Test
    func executePropagatesRequestModificationError() async {
        let executor = makeExecutorWithModifier(
            modifier: ExecThrowingRequestInterceptor(),
            cacheStorage: nil
        )

        do {
            _ = try await executor.execute()
            Issue.record("期望请求修改错误")
        } catch let error as ExecRequestModificationError {
            #expect(error == .failed)
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
    }

    @Test
    func loadCachePropagatesRequestModificationError() async {
        let executor = makeExecutorWithModifier(
            modifier: ExecThrowingRequestInterceptor(),
            cacheStorage: ExecMockCacheStorage(
                cacheData: true,
                hasCacheResult: true
            )
        )

        do {
            _ = try await executor.loadCache()
            Issue.record("期望请求修改错误")
        } catch let error as ExecRequestModificationError {
            #expect(error == .failed)
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
    }

    @Test
    func hasCacheDataReturnsFalseWithoutTouchingStorageWhenModificationFails() async {
        let capture = ExecCacheRequestCapture()
        let storage = ExecCapturingCacheStorage(capture: capture)
        let executor = makeExecutorWithModifier(
            modifier: ExecThrowingRequestInterceptor(),
            cacheStorage: storage
        )

        let result = await executor.hasCacheData()

        #expect(result == false)
        #expect(await capture.storageCalls() == 0)
    }

    @Test(arguments: [
        nil as NtkCacheConfiguration?,
        NtkCacheConfiguration(cacheTime: 0),
        NtkCacheConfiguration(cacheTime: .nan)
    ])
    func disabledCacheConfigurationNeverTouchesStorage(
        configuration: NtkCacheConfiguration?
    ) async throws {
        let capture = ExecCacheRequestCapture()
        let storage = ExecCapturingCacheStorage(capture: capture)
        let request = NtkMutableRequest(ExecDummyRequest(cacheConfiguration: configuration))
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(storage: storage)
            ]
        ))

        let cachedResponse = try await executor.loadCache()
        let hasCacheData = await executor.hasCacheData()
        let response = try await executor.execute()

        #expect(cachedResponse == nil)
        #expect(hasCacheData == false)
        #expect(response.data == true)
        #expect(await capture.storageCalls() == 0)
    }

    @Test
    func requestIdentityBuildFailureSkipsCacheButStillExecutesNetwork() async throws {
        let capture = ExecCacheRequestCapture()
        let logCapture = ExecLogCapture()
        let storage = ExecCapturingCacheStorage(capture: capture)
        let sensitiveParameter = "cache-enabled-parameter-secret"
        var builder = NtkConfiguration.Builder()
        builder.isLoggingEnabled = true
        let loggingConfiguration = NtkConfiguration(builder: builder)
        var request = NtkMutableRequest(
            ExecDummyRequest(cacheConfiguration: .default())
        )
        request.setParameter(
            ExecSensitiveUnsupportedIdentityValue(secret: sensitiveParameter),
            forKey: "unsupported"
        )
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(storage: storage)
            ],
            globalConfiguration: loggingConfiguration
        ))

        let (cachedResponse, hasCacheData, response) = try await NtkLogger.withTestSink({ record in
            logCapture.append(record)
        }) {
            try await NtkConfiguration.withTestConfiguration(loggingConfiguration) {
                let cachedResponse = try await executor.loadCache()
                let hasCacheData = await executor.hasCacheData()
                let response = try await executor.execute()
                return (cachedResponse, hasCacheData, response)
            }
        }

        #expect(cachedResponse == nil)
        #expect(hasCacheData == false)
        #expect(response.data == true)
        #expect(await capture.storageCalls() == 0)
        let unavailableRecords = logCapture.records.filter {
            $0.message.hasPrefix("[RequestIdentity] unavailable")
        }
        #expect(unavailableRecords.count == 3)
        #expect(unavailableRecords.allSatisfy {
            $0.level == .warning && $0.category == .requestIdentity
        })
        #expect(unavailableRecords.allSatisfy {
            !$0.message.contains(sensitiveParameter)
        })
    }

    @Test
    func cacheOperationsWithoutProviderSkipRequestModification() async throws {
        let executor = makeExecutorWithModifier(
            modifier: ExecThrowingRequestInterceptor(),
            cacheStorage: nil
        )

        let cachedResponse = try await executor.loadCache()
        let hasCache = await executor.hasCacheData()

        #expect(cachedResponse == nil)
        #expect(hasCache == false)
    }

    @Test
    func loadCacheDoesNotExecuteOrdinaryInterceptors() async throws {
        let counter = ExecCallCounter()
        let storage = ExecMockCacheStorage(
            cacheData: true,
            hasCacheResult: true
        )
        var request = NtkMutableRequest(
            ExecDummyRequest(
                path: "/executor/cache-side-effects",
                cacheConfiguration: .default()
            )
        )
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(storage: storage),
                ExecPriorityRecordingInterceptor(
                    id: "ordinary",
                    prio: .high,
                    counter: counter
                )
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        _ = try await executor.loadCache()

        #expect(await counter.log().isEmpty)
    }

    @Test
    func stableParametersParticipateAndExcludedDynamicParametersShareCacheRequestIdentity() async throws {
        let cacheState = ExecInMemoryCacheState()
        let dynamicSource = ExecDynamicParameterSource()
        var request = NtkMutableRequest(
            ExecDummyRequest(
                path: "/executor/cache-request-identity",
                cacheConfiguration: .default()
            )
        )
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                NtkCacheInterceptor(
                    storage: ExecInMemoryCacheStorage(state: cacheState)
                ),
                ExecCacheRequestIdentityModifier(source: dynamicSource)
            ]
        )
        let executor = NtkNetworkExecutor<Bool>(config: config)

        let networkResponse = try await executor.execute()
        let cacheResponse = try #require(await executor.loadCache())
        let savedKey = try #require(await cacheState.savedKey())
        let loadedKey = try #require(await cacheState.loadedKey())

        #expect(networkResponse.request.parameters?["tenant"] as? String == "coo")
        #expect(cacheResponse.request.parameters?["tenant"] as? String == "coo")
        #expect(networkResponse.request.parameters?["token"] as? String == "token-1")
        #expect(cacheResponse.request.parameters?["token"] as? String == "token-2")
        #expect(savedKey == loadedKey)
    }

    @Test
    func executorFreezesPolicyTimeoutAndNamespace() async throws {
        var builder = NtkConfiguration.Builder()
        builder.defaultTimeout = 45
        builder.requestIdentityPolicy = .init(excludedParameterNames: ["timestamp"])
        let global = NtkConfiguration(builder: builder)
        let capture = ExecPreparedContextCapture()
        var request = NtkMutableRequest(ExecSnapshotRequest(timeout: .nan))
        request.setParameter(123, forKey: "timestamp")
        let expectedRequestIdentity = try NtkRequestIdentityBuilder.build(
            request: request,
            policy: builder.requestIdentityPolicy
        )
        let config = NtkNetworkExecutor<Bool>.Configuration(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecPreparedContextInterceptor(capture: capture)
            ],
            globalConfiguration: global,
            deduplicationNamespace: "account-a"
        )

        _ = try await NtkNetworkExecutor<Bool>(config: config).execute()

        #expect(await capture.effectiveTimeout() == 45)
        #expect(await capture.namespace() == "account-a")
        #expect(await capture.responseType() == ObjectIdentifier(Bool.self))
        #expect(await capture.requestIdentity() == expectedRequestIdentity)
    }

    @Test
    func unsupportedRequestIdentityValueKeepsNetworkAvailableAndDisablesSharing() async throws {
        let capture = ExecPreparedContextCapture()
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/request-identity-failure"))
        request.setParameter(UnsupportedExecRequestIdentityValue(), forKey: "custom")
        let executor = makeExecutorCapturingPreparedContext(request: request, capture: capture)

        let response = try await executor.execute()

        #expect(response.data == true)
        #expect(await capture.requestIdentity() == nil)
        #expect(await capture.deduplicationKey() == nil)
    }

    @Test
    func unsupportedRequestIdentityValueStillUsesFrameworkTimeout() async {
        var request = NtkMutableRequest(ExecSnapshotRequest(timeout: 0.01))
        request.setParameter(UnsupportedExecRequestIdentityValue(), forKey: "custom")
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecDelayedClient(delayNanoseconds: .max),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor())]
        ))

        do {
            _ = try await executor.execute()
            Issue.record("身份构建失败后仍应触发 framework timeout")
        } catch let NtkError.requestTimeout(reason) {
            #expect(reason.source == "Framework")
            #expect(reason.detail == "0.01s")
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
    }

    @Test
    func requestCanEnableDeduplicationWhenGlobalDefaultIsDisabled() async throws {
        var builder = NtkConfiguration.Builder()
        builder.isDeduplicationEnabled = false
        var request = NtkMutableRequest(
            ExecDummyRequest(path: "/executor/deduplication-override-enabled")
        )
        request.enableDeduplication()
        let capture = ExecPreparedContextCapture()
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecPreparedContextInterceptor(capture: capture)
            ],
            globalConfiguration: NtkConfiguration(builder: builder)
        ))

        _ = try await executor.execute()

        #expect(await capture.deduplicationKey() != nil)
    }

    @Test
    func requestInheritsDisabledGlobalDeduplicationDefault() async throws {
        var builder = NtkConfiguration.Builder()
        builder.isDeduplicationEnabled = false
        let request = NtkMutableRequest(
            ExecDummyRequest(path: "/executor/deduplication-inherit-disabled")
        )
        let capture = ExecPreparedContextCapture()
        let executor = makeExecutorCapturingPreparedContext(
            request: request,
            capture: capture,
            globalConfiguration: NtkConfiguration(builder: builder)
        )

        _ = try await executor.execute()

        #expect(await capture.deduplicationKey() == nil)
    }

    @Test
    func requestCanDisableDeduplicationWhenGlobalDefaultIsEnabled() async throws {
        var request = NtkMutableRequest(
            ExecDummyRequest(path: "/executor/deduplication-override-disabled")
        )
        request.disableDeduplication()
        let capture = ExecPreparedContextCapture()
        let executor = makeExecutorCapturingPreparedContext(request: request, capture: capture)

        _ = try await executor.execute()

        #expect(await capture.deduplicationKey() == nil)
    }

    @Test
    func requestLevelPolicyCompletelyReplacesGlobalPolicy() async throws {
        var builder = NtkConfiguration.Builder()
        builder.requestIdentityPolicy = .init(excludedParameterNames: ["tenant"])
        let global = NtkConfiguration(builder: builder)
        let capture = ExecPreparedContextCapture()
        var request = NtkMutableRequest(ExecSnapshotRequest(
            timeout: 30,
            requestIdentityPolicy: .strict
        ))
        request.setParameter("a", forKey: "tenant")
        let expected = try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [
                NtkResponseParserBox(ExecMockParsingInterceptor()),
                ExecPreparedContextInterceptor(capture: capture)
            ],
            globalConfiguration: global
        ))

        _ = try await executor.execute()

        #expect(await capture.requestIdentity() == expected)
    }

    // MARK: - request identity preparation logging

    @Test
    func executeLogsPreparedIdentityAndDeduplicationKeyWhenIdentityBuilds() async throws {
        let capture = ExecLogCapture()
        var builder = NtkConfiguration.Builder()
        builder.isLoggingEnabled = true
        let loggingConfiguration = NtkConfiguration(builder: builder)
        let sensitiveNamespace = "tenant-secret-namespace"
        let sensitiveQuery = "path-secret"
        let sensitiveFragment = "fragment-secret"
        let request = NtkMutableRequest(ExecDummyRequest(
            path: "/oauth/callback?code=\(sensitiveQuery)#\(sensitiveFragment)"
        ))
        let expectedIdentity = try NtkRequestIdentityBuilder.build(request: request, policy: .strict)
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor())],
            globalConfiguration: loggingConfiguration,
            deduplicationNamespace: sensitiveNamespace
        ))

        try await NtkLogger.withTestSink({ record in
            capture.append(record)
        }) {
            try await NtkConfiguration.withTestConfiguration(loggingConfiguration) {
                _ = try await executor.execute()
            }
        }

        let requestID = request.instanceIdentifier.uuidString
        #expect(capture.records == [
            .init(
                level: .debug,
                category: .network,
                message: "[RequestExecution] prepared requestID=\(requestID) method=POST path=/oauth/callback timeout=20.0 cache=false deduplication=true"
            ),
            .init(
                level: .debug,
                category: .requestIdentity,
                message: "[RequestIdentity] built requestID=\(requestID) identity=\(expectedIdentity.value)"
            ),
            .init(
                level: .debug,
                category: .deduplication,
                message: "[Deduplication] key-ready requestID=\(requestID) identity=\(expectedIdentity.value) timeout=20.0"
            )
        ])
        #expect(capture.records.allSatisfy { !$0.message.contains(sensitiveNamespace) })
        #expect(capture.records.allSatisfy { !$0.message.contains(sensitiveQuery) })
        #expect(capture.records.allSatisfy { !$0.message.contains(sensitiveFragment) })
    }

    @Test
    func executeLogsSkippedIdentityAndDisabledDeduplicationWithoutConsumers() async throws {
        let capture = ExecLogCapture()
        var builder = NtkConfiguration.Builder()
        builder.isLoggingEnabled = true
        builder.isDeduplicationEnabled = false
        let loggingConfiguration = NtkConfiguration(builder: builder)
        let request = NtkMutableRequest(ExecDummyRequest(path: "/executor/logging/no-consumer"))
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor())],
            globalConfiguration: loggingConfiguration
        ))

        try await NtkLogger.withTestSink({ record in
            capture.append(record)
        }) {
            try await NtkConfiguration.withTestConfiguration(loggingConfiguration) {
                _ = try await executor.execute()
            }
        }

        let requestID = request.instanceIdentifier.uuidString
        #expect(capture.records == [
            .init(
                level: .debug,
                category: .network,
                message: "[RequestExecution] prepared requestID=\(requestID) method=POST path=/executor/logging/no-consumer timeout=20.0 cache=false deduplication=false"
            ),
            .init(
                level: .debug,
                category: .requestIdentity,
                message: "[RequestIdentity] skipped requestID=\(requestID) reason=no-consumer"
            ),
            .init(
                level: .debug,
                category: .deduplication,
                message: "[Deduplication] disabled requestID=\(requestID)"
            )
        ])
    }

    @Test
    func executeLogsSanitizedIdentityBuildFailureAndDisablesDeduplication() async throws {
        let capture = ExecLogCapture()
        var builder = NtkConfiguration.Builder()
        builder.isLoggingEnabled = true
        let loggingConfiguration = NtkConfiguration(builder: builder)
        let sensitiveHeader = "Bearer header-secret-value"
        let sensitiveParameter = "parameter-secret-value"
        var request = NtkMutableRequest(ExecDummyRequest(path: "/executor/logging/identity-unavailable"))
        request.setHeader(sensitiveHeader, forField: "Authorization")
        request.setParameter(
            ExecSensitiveUnsupportedIdentityValue(secret: sensitiveParameter),
            forKey: "unsupported"
        )
        let executor = NtkNetworkExecutor<Bool>(config: .init(
            client: ExecMockClient(result: .success(())),
            request: request,
            interceptors: [NtkResponseParserBox(ExecMockParsingInterceptor())],
            globalConfiguration: loggingConfiguration
        ))

        try await NtkLogger.withTestSink({ record in
            capture.append(record)
        }) {
            try await NtkConfiguration.withTestConfiguration(loggingConfiguration) {
                _ = try await executor.execute()
            }
        }

        let requestID = request.instanceIdentifier.uuidString
        let unavailable = try #require(capture.records.first {
            $0.message.hasPrefix("[RequestIdentity] unavailable")
        })
        #expect(unavailable.level == .warning)
        #expect(unavailable.category == .requestIdentity)
        #expect(unavailable.message.contains("requestID=\(requestID)"))
        #expect(unavailable.message.contains("cache=false deduplication=false"))
        #expect(!unavailable.message.contains(sensitiveHeader))
        #expect(!unavailable.message.contains(sensitiveParameter))
        #expect(capture.records.contains(.init(
            level: .debug,
            category: .deduplication,
            message: "[Deduplication] disabled requestID=\(requestID)"
        )))
    }
}

// MARK: - Factory Helpers

private func makeExecutor(
    client: ExecMockClient,
    cacheInterceptor: NtkCacheInterceptor? = nil,
    parsingInterceptor: any iNtkResponseParser
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest(
        cacheConfiguration: cacheInterceptor == nil ? nil : .default()
    ))
    var interceptors: [iNtkInterceptor] = [NtkResponseParserBox(parsingInterceptor)]
    if let cacheInterceptor { interceptors.append(cacheInterceptor) }
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: client,
        request: request,
        interceptors: interceptors
    )
    return NtkNetworkExecutor<Bool>(config: config)
}

private func makeBoolExecutor(
    client: ExecMockClient,
    cacheInterceptor: NtkCacheInterceptor? = nil
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest(
        cacheConfiguration: cacheInterceptor == nil ? nil : .default()
    ))
    var interceptors: [iNtkInterceptor] = [NtkResponseParserBox(ExecMockParsingInterceptor())]
    if let cacheInterceptor { interceptors.append(cacheInterceptor) }
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: client,
        request: request,
        interceptors: interceptors
    )
    return NtkNetworkExecutor<Bool>(config: config)
}

private func makeExecutorWithModifier(
    modifier: any iNtkRequestModifyingInterceptor,
    cacheStorage: (any iNtkCacheStorage)?
) -> NtkNetworkExecutor<Bool> {
    var request = NtkMutableRequest(ExecDummyRequest(
        path: "/executor/modifier-error",
        cacheConfiguration: cacheStorage == nil ? nil : .default()
    ))
    var interceptors: [iNtkInterceptor] = [
        NtkResponseParserBox(ExecMockParsingInterceptor()),
        modifier
    ]
    if let cacheStorage {
        interceptors.append(NtkCacheInterceptor(storage: cacheStorage))
    }
    let config = NtkNetworkExecutor<Bool>.Configuration(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: interceptors
    )
    return NtkNetworkExecutor<Bool>(config: config)
}

private func makeExecutorCapturingPreparedContext(
    request: NtkMutableRequest,
    capture: ExecPreparedContextCapture,
    globalConfiguration: NtkConfiguration = .current
) -> NtkNetworkExecutor<Bool> {
    NtkNetworkExecutor(config: .init(
        client: ExecMockClient(result: .success(())),
        request: request,
        interceptors: [
            NtkResponseParserBox(ExecMockParsingInterceptor()),
            ExecPreparedContextInterceptor(capture: capture)
        ],
        globalConfiguration: globalConfiguration
    ))
}

private func makeCacheClientResponse() -> NtkClientResponse {
    var request = NtkMutableRequest(ExecDummyRequest())
    return NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: true)
}

// MARK: - Test Doubles

private struct ExecDummyRequest: iNtkRequest {
    let path: String
    let cacheConfiguration: NtkCacheConfiguration?

    init(
        path: String = "/executor/test",
        cacheConfiguration: NtkCacheConfiguration? = nil
    ) {
        self.path = path
        self.cacheConfiguration = cacheConfiguration
    }
}

private struct ExecSnapshotRequest: iNtkRequest {
    let timeout: TimeInterval
    let requestIdentityPolicy: NtkRequestIdentityPolicy?
    var path: String { "/executor/snapshot" }

    init(
        timeout: TimeInterval,
        requestIdentityPolicy: NtkRequestIdentityPolicy? = nil
    ) {
        self.timeout = timeout
        self.requestIdentityPolicy = requestIdentityPolicy
    }
}

private struct UnsupportedExecRequestIdentityValue: Sendable {}

private struct ExecSensitiveUnsupportedIdentityValue: Sendable {
    let secret: String
}

private final class ExecLogCapture: @unchecked Sendable {
    private let lock = NtkUnfairLock()
    private var storage: [NtkLogger.LogRecord] = []

    var records: [NtkLogger.LogRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ record: NtkLogger.LogRecord) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(record)
    }
}

private actor ExecPreparedContextCapture {
    private var context: NtkInterceptorContext?

    func record(_ context: NtkInterceptorContext) { self.context = context }
    func effectiveTimeout() -> TimeInterval? { context?.effectiveTimeout }
    func namespace() -> String? { context?.deduplicationKey?.namespace }
    func responseType() -> ObjectIdentifier? { context?.deduplicationKey?.responseType }
    func requestIdentity() -> NtkRequestIdentity? { context?.requestIdentity }
    func deduplicationKey() -> NtkDeduplicationKey? {
        context?.deduplicationKey
    }
}

private struct ExecPreparedContextInterceptor: iNtkInterceptor {
    let capture: ExecPreparedContextCapture

    func intercept(
        context: NtkInterceptorContext,
        next: any iNtkRequestHandler
    ) async throws -> any iNtkResponse {
        await capture.record(context)
        return try await next.handle(context: context)
    }
}

private struct ExecDummyValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool { true }
}

private struct ExecTestKeys: iNtkResponseMapKeys {
    static let code = "retCode"
    static let data = "data"
    static let msg = "retMsg"
}

private struct ExecMockClient: iNtkClient {
    let result: Result<Void, Error>

    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        switch result {
        case .success:
            return NtkClientResponse(data: true, msg: nil, response: true, request: request, isCache: false)
        case .failure(let error):
            throw error
        }
    }
}

private struct ExecDelayedClient: iNtkClient {
    let delayNanoseconds: UInt64

    func execute(_ request: NtkMutableRequest) async throws -> NtkClientResponse {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return NtkClientResponse(
            data: true,
            msg: nil,
            response: true,
            request: request,
            isCache: false
        )
    }
}

private struct ExecMockCacheStorage: iNtkCacheStorage {
    let cacheData: (any Sendable)?
    let hasCacheResult: Bool

    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool { false }
    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        guard let cacheData else { return nil }
        return NtkCacheMeta(
            appVersion: "1.0",
            creationDate: Date().timeIntervalSince1970,
            expirationDate: Date().timeIntervalSince1970 + 3600,
            data: cacheData
        )
    }
    func hasData(key: String, for request: NtkMutableRequest) async -> Bool { hasCacheResult }
}

private final class ExecThrowingHook: iNtkParsingHooks, @unchecked Sendable {
    var events: [String] = []

    func didDecodeHeader(retCode: Int, msg: String?, context: NtkParsingContext) async throws {
        events.append("didDecodeHeader")
        throw ExecHookObserverError.point("didDecodeHeader")
    }

    func willValidate(_ response: any iNtkResponse, context: NtkParsingContext) async throws {
        events.append("willValidate")
        throw ExecHookObserverError.point("willValidate")
    }

    func didComplete(_ response: any iNtkResponse, context: NtkParsingContext) async throws {
        events.append("didComplete")
        throw ExecHookObserverError.point("didComplete")
    }
}

private enum ExecHookObserverError: Error, Equatable {
    case point(String)
}

/// 将 NtkClientResponse 转为 NtkResponse<Bool> 的 mock 解析拦截器
private struct ExecMockParsingInterceptor: iNtkResponseParser {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        if let typed = response as? NtkResponse<Bool> { return typed }
        return NtkResponse<Bool>(
            code: response.code,
            data: true,
            msg: response.msg,
            response: response.response,
            request: response.request,
            isCache: response.isCache
        )
    }
}

private struct ExecPassThroughParser: iNtkResponseParser {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
}

/// 记录执行顺序的拦截器
private struct ExecPriorityRecordingInterceptor: iNtkInterceptor {
    let id: String
    let prio: NtkInterceptorPriority
    let counter: ExecCallCounter

    nonisolated var priority: NtkInterceptorPriority { prio }

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        await counter.record(id)
        return try await next.handle(context: context)
    }
}

private struct ExecLookalikeRequestInterceptor: iNtkInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.setHeader("unexpected", forField: "X-Lookalike-Modifier")
        return request
    }

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        try await next.handle(context: context)
    }
}

private struct ExecCombinedRequestInterceptor: iNtkRequestModifyingInterceptor {
    let counter: ExecCallCounter

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.setHeader("modified", forField: "X-Combined")
        return request
    }

    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)
        await counter.record("intercept")
        return response
    }
}

private struct ExecIncrementingRequestInterceptor: iNtkRequestModifyingInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        let previousValue = Int(request.headers?["X-Execution-Count"] ?? "") ?? 0
        request.setHeader(String(previousValue + 1), forField: "X-Execution-Count")
        return request
    }
}

private struct ExecStableRequestInterceptor: iNtkRequestModifyingInterceptor {
    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        request.setHeader("stable", forField: "X-Stable-Parameter")
        return request
    }
}

private struct ExecAppendingRequestInterceptor: iNtkRequestModifyingInterceptor {
    let id: String
    let prio: NtkInterceptorPriority

    nonisolated var priority: NtkInterceptorPriority { prio }

    func modifyRequest(_ request: NtkMutableRequest) async throws -> NtkMutableRequest {
        var request = request
        let existing = request.headers?["X-Modifier-Order"]
        let value = [existing, id].compactMap { $0 }.joined(separator: ",")
        request.setHeader(value, forField: "X-Modifier-Order")
        return request
    }
}

private enum ExecRequestModificationError: Error, Equatable {
    case failed
}

private struct ExecThrowingRequestInterceptor: iNtkRequestModifyingInterceptor {
    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest {
        throw ExecRequestModificationError.failed
    }
}

private actor ExecDynamicParameterSource {
    private var value = 0

    func nextToken() -> String {
        value += 1
        return "token-\(value)"
    }
}

private struct ExecCacheRequestIdentityModifier: iNtkRequestModifyingInterceptor {
    let source: ExecDynamicParameterSource

    func modifyRequest(
        _ request: NtkMutableRequest
    ) async throws -> NtkMutableRequest {
        var request = request
        request.setParameter(
            "coo",
            forKey: "tenant",
            requestIdentityRule: .include
        )
        request.setParameter(
            await source.nextToken(),
            forKey: "token",
            requestIdentityRule: .exclude
        )
        return request
    }
}

private actor ExecInMemoryCacheState {
    private var entries: [String: NtkCacheMeta] = [:]
    private var lastSavedKey: String?
    private var lastLoadedKey: String?

    func set(_ metaData: NtkCacheMeta, for key: String) -> Bool {
        entries[key] = metaData
        lastSavedKey = key
        return true
    }

    func get(_ key: String) -> NtkCacheMeta? {
        lastLoadedKey = key
        return entries[key]
    }

    func contains(_ key: String) -> Bool {
        entries[key] != nil
    }

    func savedKey() -> String? {
        lastSavedKey
    }

    func loadedKey() -> String? {
        lastLoadedKey
    }
}

private struct ExecInMemoryCacheStorage: iNtkCacheStorage {
    let state: ExecInMemoryCacheState

    func setData(
        metaData: NtkCacheMeta,
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await state.set(metaData, for: key)
    }

    func getData(
        key: String,
        for request: NtkMutableRequest
    ) async -> NtkCacheMeta? {
        await state.get(key)
    }

    func hasData(
        key: String,
        for request: NtkMutableRequest
    ) async -> Bool {
        await state.contains(key)
    }
}

private actor ExecCacheRequestCapture {
    private var headers: [String: String] = [:]
    private var storageCallCount = 0

    func recordStorageCall(_ request: NtkMutableRequest) {
        headers = request.headers ?? [:]
        storageCallCount += 1
    }

    func headerValue(for key: String) -> String? {
        headers[key]
    }

    func storageCalls() -> Int {
        storageCallCount
    }
}

private struct ExecCapturingCacheStorage: iNtkCacheStorage {
    let capture: ExecCacheRequestCapture

    func setData(metaData: NtkCacheMeta, key: String, for request: NtkMutableRequest) async -> Bool {
        await capture.recordStorageCall(request)
        return false
    }

    func getData(key: String, for request: NtkMutableRequest) async -> NtkCacheMeta? {
        await capture.recordStorageCall(request)
        return nil
    }

    func hasData(key: String, for request: NtkMutableRequest) async -> Bool {
        await capture.recordStorageCall(request)
        return true
    }
}

private actor ExecCallCounter {
    private var entries: [String] = []
    func record(_ id: String) { entries.append(id) }
    func log() -> [String] { entries }
}
