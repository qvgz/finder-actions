import Foundation
import OSLog

enum Diagnostics {
    static let enabledKey = "diagnosticsEnabled"
    static let subsystem = "io.github.qvgz.FinderActions"

    private static let logger = Logger(subsystem: subsystem, category: "diagnostics")

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func log(_ message: String, defaults: UserDefaults) {
        guard isEnabled(in: defaults) else { return }
        logger.notice("\(message, privacy: .public)")
    }
}
