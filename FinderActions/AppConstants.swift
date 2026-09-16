import Foundation

enum AppConstants {
    static let extensionBundleIdentifier = "io.github.qvgz.FinderActions.Extension"
    static let sharedPreferencesDomain = "io.github.qvgz.FinderActions.Shared"
    static let urlScheme = "finder-actions"
    static let monitoredDirectoriesKey = "monitoredDirectories"
    static let monitoredDirectoriesConfiguredKey = "monitoredDirectoriesConfigured"

    static var sharedDefaults: UserDefaults {
        let defaults = UserDefaults(suiteName: sharedPreferencesDomain) ?? .standard
        migrateLegacyDefaultsIfNeeded(to: defaults)
        return defaults
    }

    private static func migrateLegacyDefaultsIfNeeded(to defaults: UserDefaults) {
        let migrationKey = "sharedPreferencesMigrated"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let legacyDomain = UserDefaults.standard.persistentDomain(forName: extensionBundleIdentifier) ?? [:]
        let keys = [
            "finderActions",
            "alacrittyEnabled",
            "codeEnabled",
            monitoredDirectoriesKey,
            monitoredDirectoriesConfiguredKey,
            Diagnostics.enabledKey
        ]
        for key in keys {
            if let value = legacyDomain[key] {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: migrationKey)
        defaults.synchronize()
    }
}
