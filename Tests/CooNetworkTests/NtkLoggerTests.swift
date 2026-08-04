import Testing
@testable import CooNetwork

struct NtkLoggerTests {
    @Test
    func disabledLoggingFiltersDebugAndInfoButKeepsWarningAndAbove() async {
        let capture = LogCapture()
        await NtkLogger.withTestSink({ record in
            capture.append(record)
        }) {
            await NtkConfiguration.withTestConfiguration(loggingConfiguration(enabled: false)) {
                logger.debug("debug", category: .network)
                logger.info("info", category: .network)
                logger.warning("warning", category: .network)
                logger.error("error", category: .network)
                logger.fault("fault", category: .network)
            }
        }

        #expect(capture.records == [
            .init(level: .warning, category: .network, message: "warning"),
            .init(level: .error, category: .network, message: "error"),
            .init(level: .fault, category: .network, message: "fault")
        ])
    }

    @Test
    func nestedConfigurationImmediatelyEnablesDebugLogsForChildTasks() async {
        let capture = LogCapture()
        await NtkLogger.withTestSink({ record in
            capture.append(record)
        }) {
            await NtkConfiguration.withTestConfiguration(loggingConfiguration(enabled: false)) {
                logger.debug("before-enable", category: .network)

                await NtkConfiguration.withTestConfiguration(loggingConfiguration(enabled: true)) {
                    let task = Task {
                        logger.debug("after-enable", category: .network)
                    }
                    await task.value
                }
            }
        }

        #expect(capture.records == [
            .init(level: .debug, category: .network, message: "after-enable")
        ])
    }
}

private func loggingConfiguration(enabled: Bool) -> NtkConfiguration {
    var builder = NtkConfiguration.Builder()
    builder.isLoggingEnabled = enabled
    return NtkConfiguration(builder: builder)
}

private final class LogCapture: @unchecked Sendable {
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
