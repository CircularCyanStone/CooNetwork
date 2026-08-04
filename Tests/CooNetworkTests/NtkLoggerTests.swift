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

        logger.debug("debug", category: .network)
        logger.info("info", category: .network)
        logger.warning("warning", category: .network)
        logger.error("error", category: .network)
        logger.fault("fault", category: .network)

        #expect(capture.records == [
            .init(level: .warning, category: .network, message: "warning"),
            .init(level: .error, category: .network, message: "error"),
            .init(level: .fault, category: .network, message: "fault")
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
        logger.debug("before-enable", category: .network)

        NtkConfiguration.configure { $0.isLoggingEnabled = true }
        logger.debug("after-enable", category: .network)

        #expect(capture.records == [
            .init(level: .debug, category: .network, message: "after-enable")
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

    func append(_ record: NtkLogger.LogRecord) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(record)
    }
}
