import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()

    override init() {
        super.init()
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }

        let menu = NSMenu(title: "Finder Actions")
        let defaults = UserDefaults(suiteName: AppConstants.extensionBundleIdentifier) ?? .standard

        if defaults.object(forKey: AppConstants.alacrittyEnabledKey) as? Bool ?? true {
            menu.addItem(withTitle: "Alacritty", action: #selector(openAlacritty), keyEquivalent: "")
        }
        if defaults.object(forKey: AppConstants.codeEnabledKey) as? Bool ?? true {
            menu.addItem(withTitle: "Code", action: #selector(openCode), keyEquivalent: "")
        }

        return menu.items.isEmpty ? nil : menu
    }

    @objc private func openAlacritty() {
        open(action: "alacritty")
    }

    @objc private func openCode() {
        open(action: "code")
    }

    private func open(action: String) {
        guard let directoryURL = targetDirectoryURL() else { return }

        var components = URLComponents()
        components.scheme = AppConstants.urlScheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "path", value: directoryURL.path)
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func targetDirectoryURL() -> URL? {
        if let selectedURL = controller.selectedItemURLs()?.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return selectedURL
            }
            return selectedURL.deletingLastPathComponent()
        }

        return controller.targetedURL()
    }
}
