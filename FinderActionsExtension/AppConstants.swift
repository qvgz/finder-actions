import Foundation

enum AppConstants {
    static let extensionBundleIdentifier = "io.github.qvgz.FinderActions.Extension"
    static let urlScheme = "finder-actions"
    static let monitoredDirectoriesKey = "monitoredDirectories"
    static let monitoredDirectoriesConfiguredKey = "monitoredDirectoriesConfigured"

    // The containing app writes this extension's preferences domain. Inside
    // the sandbox, the extension must read that domain through standard.
    static var sharedDefaults: UserDefaults { .standard }
}
