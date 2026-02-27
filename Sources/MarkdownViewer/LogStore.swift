import Foundation
import Observation
import OSLog

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let level: Level
    let category: String
    let message: String

    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}

@Observable
final class LogStore {
    static let shared = LogStore()
    private(set) var entries: [LogEntry] = []

    private init() {}

    func log(_ message: String, level: LogEntry.Level = .info, category: String = "general") {
        let osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MarkdownViewer", category: category)
        switch level {
        case .debug:   osLogger.debug("\(message)")
        case .info:    osLogger.info("\(message)")
        case .warning: osLogger.warning("\(message)")
        case .error:   osLogger.error("\(message)")
        }
        entries.append(LogEntry(date: .now, level: level, category: category, message: message))
    }

    func clear() {
        entries.removeAll()
    }
}
