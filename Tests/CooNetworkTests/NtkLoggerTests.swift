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

    @Test
    func globalConfigurationImmediatelyChangesEveryObservableLogLevel() async {
        let originalConfiguration = NtkConfiguration.current
        defer {
            NtkConfiguration.configure { $0 = originalConfiguration.builder }
        }

        let prefix = "ntk-logger-global-config-"
        let capture = LogCapture()
        await NtkLogger.withTestSink({ record in
            capture.append(record)
        }) {
            NtkConfiguration.configure { $0.isLoggingEnabled = false }
            logger.debug("\(prefix)disabled-debug", category: .network)
            logger.info("\(prefix)disabled-info", category: .network)
            logger.warning("\(prefix)disabled-warning", category: .network)
            logger.error("\(prefix)disabled-error", category: .network)
            logger.fault("\(prefix)disabled-fault", category: .network)

            NtkConfiguration.configure { $0.isLoggingEnabled = true }
            logger.debug("\(prefix)enabled-debug", category: .network)
            logger.info("\(prefix)enabled-info", category: .network)
            logger.warning("\(prefix)enabled-warning", category: .network)
            logger.error("\(prefix)enabled-error", category: .network)
            logger.fault("\(prefix)enabled-fault", category: .network)
        }

        #expect(capture.records(withMessagePrefix: prefix) == [
            .init(level: .warning, category: .network, message: "\(prefix)disabled-warning"),
            .init(level: .error, category: .network, message: "\(prefix)disabled-error"),
            .init(level: .fault, category: .network, message: "\(prefix)disabled-fault"),
            .init(level: .debug, category: .network, message: "\(prefix)enabled-debug"),
            .init(level: .info, category: .network, message: "\(prefix)enabled-info"),
            .init(level: .warning, category: .network, message: "\(prefix)enabled-warning"),
            .init(level: .error, category: .network, message: "\(prefix)enabled-error"),
            .init(level: .fault, category: .network, message: "\(prefix)enabled-fault")
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

    func records(withMessagePrefix prefix: String) -> [NtkLogger.LogRecord] {
        records.filter { $0.message.hasPrefix(prefix) }
    }

    func append(_ record: NtkLogger.LogRecord) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(record)
    }
}
