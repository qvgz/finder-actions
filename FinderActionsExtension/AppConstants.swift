import Foundation

enum AppConstants {
    static let sharedPreferencesDomain = "io.github.qvgz.FinderActions.Shared"
    static let urlScheme = "finder-actions"
    static let monitoredDirectoriesKey = "monitoredDirectories"
    static let monitoredDirectoriesConfiguredKey = "monitoredDirectoriesConfigured"
    static let interfaceLanguageKey = "interfaceLanguage"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: sharedPreferencesDomain) ?? .standard
    }
}
