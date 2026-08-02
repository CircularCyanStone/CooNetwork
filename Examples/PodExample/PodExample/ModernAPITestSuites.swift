import Foundation
import CooNetwork

func testT9_RequestModification() -> TestSuite {
    TestSuite(
        name: "T9: 请求修改测试",
        description: "验证请求修改器写入参数、请求头和请求元数据"
    ) {
        let startTime = Date()
        let request = HttpBinRequest(path: "/anything", method: .get, parameters: nil)
        let network = NtkAF<HttpBinResponse>.withAF(
            request,
            validation: StandardValidation(),
            responseParser: DirectDataParsingInterceptor<HttpBinResponse>()
        )
        network.addInterceptor(EchoRequestModifier())

        do {
            let response = try await network.request()
            let parameterValue = response.data.args["modifier"]
            let headerValue = headerValue(
                in: response.data.headers,
                named: "X-Request-Modifier"
            )

            guard parameterValue == "applied" else {
                throw TestError.validationFailed(
                    "修改后的参数未到达服务端，实际值: \(parameterValue ?? "nil")"
                )
            }
            guard headerValue == "applied" else {
                throw TestError.validationFailed(
                    "修改后的请求头未到达服务端，实际值: \(headerValue ?? "nil")"
                )
            }

            return TestResult(
                name: "T9: 请求修改测试",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                details: "服务端回显了修改器写入的参数和请求头",
                evidence: "modifier=\(parameterValue ?? "nil"), X-Request-Modifier=\(headerValue ?? "nil")"
            )
        } catch {
            return failedResult(
                name: "T9: 请求修改测试",
                startTime: startTime,
                error: error
            )
        }
    }
}

func testT10_RequestModifierOrdering() -> TestSuite {
    TestSuite(
        name: "T10: 修改器顺序测试",
        description: "验证同优先级请求修改器保持注册顺序"
    ) {
        let startTime = Date()
        let request = HttpBinRequest(path: "/anything", method: .get, parameters: nil)
        let network = NtkAF<HttpBinResponse>.withAF(
            request,
            validation: StandardValidation(),
            responseParser: DirectDataParsingInterceptor<HttpBinResponse>()
        )
        network.addInterceptor(TraceRequestModifier(value: "first"))
        network.addInterceptor(TraceRequestModifier(value: "second"))

        do {
            let response = try await network.request()
            let trace = headerValue(
                in: response.data.headers,
                named: "X-Modifier-Trace"
            )
            guard trace == "first,second" else {
                throw TestError.validationFailed(
                    "期望 first,second，实际 \(trace ?? "nil")"
                )
            }

            return TestResult(
                name: "T10: 修改器顺序测试",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                details: "同优先级修改器按注册顺序构建请求",
                evidence: "X-Modifier-Trace=\(trace ?? "nil")"
            )
        } catch {
            return failedResult(
                name: "T10: 修改器顺序测试",
                startTime: startTime,
                error: error
            )
        }
    }
}

func testT11_ContextValueFlow() -> TestSuite {
    TestSuite(
        name: "T11: 上下文值流测试",
        description: "验证 extraData 通过上下文副本向下游传播"
    ) {
        let startTime = Date()
        let probe = ContextFlowProbe()
        let request = HttpBinRequest(path: "/get", method: .get, parameters: nil)
        let network = NtkAF<HttpBinResponse>.withAF(
            request,
            validation: StandardValidation(),
            responseParser: DirectDataParsingInterceptor<HttpBinResponse>()
        )
        network.addInterceptor(ContextWritingInterceptor(probe: probe))
        network.addInterceptor(ContextReadingInterceptor(probe: probe))

        do {
            _ = try await network.request()
            let snapshot = await probe.snapshot()

            guard snapshot.writerInput == nil else {
                throw TestError.validationFailed("上游上下文不应预先包含 context-trace")
            }
            guard snapshot.readerInput == "propagated" else {
                throw TestError.validationFailed(
                    "下游未收到上下文副本，实际值: \(snapshot.readerInput ?? "nil")"
                )
            }

            return TestResult(
                name: "T11: 上下文值流测试",
                status: .passed,
                duration: Date().timeIntervalSince(startTime),
                details: "上游值保持为空，下游读取到 propagated",
                evidence: "writerInput=nil, readerInput=\(snapshot.readerInput ?? "nil")"
            )
        } catch {
            return failedResult(
                name: "T11: 上下文值流测试",
                startTime: startTime,
                error: error
            )
        }
    }
}

private func failedResult(
    name: String,
    startTime: Date,
    error: Error
) -> TestResult {
    TestResult(
        name: name,
        status: .failed,
        duration: Date().timeIntervalSince(startTime),
        details: "测试失败: \(error.localizedDescription)",
        evidence: nil
    )
}
