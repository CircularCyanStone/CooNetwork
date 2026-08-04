import Testing
@testable import CooNetwork

@Suite(.serialized)
struct NtkLoggerTests {
    @Test
    func disabledLoggingFiltersDebugAndInfoButKeepsWarningAndAbove() {
        let originalConfiguration = NtkConfiguration.current.builder
        let capture = LogCapture()
        let originalSink = NtkLogger.installTestSink { record in
            capture.append(record)
        }
        defer {
            NtkConfiguration.configure { $0 = originalConfiguration }
            _ = NtkLogger.installTestSink(originalSink)
        }

        NtkConfiguration.configure { $0.isLoggingEnabled = false }

        logger.error("unrelated-concurrent-log", category: .retry)
        let messages = [
            "logger-test-debug",
            "logger-test-info",
            "logger-test-warning",
            "logger-test-error",
            "logger-test-fault"
        ]
        logger.debug(messages[0], category: .network)
        logger.info(messages[1], category: .network)
        logger.warning(messages[2], category: .network)
        logger.error(messages[3], category: .network)
        logger.fault(messages[4], category: .network)

        #expect(capture.records(matchingMessages: messages) == [
            .init(level: .warning, category: .network, message: messages[2]),
            .init(level: .error, category: .network, message: messages[3]),
            .init(level: .fault, category: .network, message: messages[4])
        ])
    }

    @Test
    func enablingLoggingAtRuntimeImmediatelyAllowsDebugLogs() {
        let originalConfiguration = NtkConfiguration.current.builder
        let capture = LogCapture()
        let originalSink = NtkLogger.installTestSink { record in
            capture.append(record)
        }
        defer {
            NtkConfiguration.configure { $0 = originalConfiguration }
            _ = NtkLogger.installTestSink(originalSink)
        }

        NtkConfiguration.configure { $0.isLoggingEnabled = false }
        let messages = ["logger-test-before-enable", "logger-test-after-enable"]
        logger.debug(messages[0], category: .network)

        NtkConfiguration.configure { $0.isLoggingEnabled = true }
        logger.debug(messages[1], category: .network)

        #expect(capture.records(matchingMessages: messages) == [
            .init(level: .debug, category: .network, message: messages[1])
        ])
    }
}

private final class LogCapture: @unchecked Sendable {
    private let lock = NtkUnfairLock()
    private var storage: [NtkLogger.LogRecord] = []

    var records: [NtkLogger.LogRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func records(matchingMessages messages: [String]) -> [NtkLogger.LogRecord] {
        records.filter { messages.contains($0.message) }
    }

    func append(_ record: NtkLogger.LogRecord) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(record)
    }
}
