import AppKit
import Darwin
import FinderSync

final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()

    override init() {
        super.init()
        refreshMonitoredDirectoryURLs()

        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(volumesDidChange(_:)),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(volumesDidChange(_:)),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(volumesDidChange(_:)),
            name: NSWorkspace.didRenameVolumeNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }

        let menu = NSMenu(title: "Finder Actions")
        let defaults = UserDefaults(suiteName: AppConstants.extensionBundleIdentifier) ?? .standard
        for action in FinderActionStore.load(from: defaults) {
            let menuItem = menu.addItem(
                withTitle: action.name,
                action: #selector(runFinderAction(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = action.id
        }

        return menu.items.isEmpty ? nil : menu
    }

    @objc private func runFinderAction(_ sender: NSMenuItem) {
        guard let actionID = sender.representedObject as? String,
              let selectedTargetURL = targetURL()
        else { return }

        var components = URLComponents()
        components.scheme = AppConstants.urlScheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "action", value: actionID),
            URLQueryItem(name: "path", value: selectedTargetURL.path)
        ]

        if let url = components.url {
            let configuration = NSWorkspace.OpenConfiguration()
            // The host is only a launcher. Activating it would make Finder lose
            // focus once before Alacritty or Code becomes the foreground app.
            configuration.activates = false
            NSWorkspace.shared.open(url, configuration: configuration)
        }
    }

    private func targetURL() -> URL? {
        if let selectedURL = controller.selectedItemURLs()?.first {
            return selectedURL
        }

        return controller.targetedURL()
    }

    private func monitoredDirectoryURLs() -> Set<URL> {
        let defaults = UserDefaults(suiteName: AppConstants.extensionBundleIdentifier) ?? .standard
        if defaults.bool(forKey: AppConstants.monitoredDirectoriesConfiguredKey) {
            let paths = defaults.stringArray(forKey: AppConstants.monitoredDirectoriesKey) ?? []
            let configuredURLs = Set(paths.map {
                URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
            })
            return addingMountedVolumes(to: configuredURLs)
        }

        var urls: Set<URL> = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true)
        ]

        guard let passwordEntry = getpwuid(getuid()) else { return urls }

        let homeURL = URL(
            fileURLWithPath: String(cString: passwordEntry.pointee.pw_dir),
            isDirectory: true
        )
        urls.insert(homeURL)

        return addingMountedVolumes(to: urls)
    }

    private func addingMountedVolumes(to configuredURLs: Set<URL>) -> Set<URL> {
        let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []

        var urls = configuredURLs
        for volumeURL in mountedVolumes {
            let standardizedVolumeURL = volumeURL.standardizedFileURL
            if configuredURLs.contains(where: { contains(standardizedVolumeURL, in: $0) }) {
                // A monitored directory such as /Volumes does not reliably cross a
                // mount point, so register the mounted volume as a root as well.
                urls.insert(standardizedVolumeURL)
            }
        }
        return urls
    }

    private func contains(_ candidateURL: URL, in directoryURL: URL) -> Bool {
        let directoryComponents = directoryURL.pathComponents
        let candidateComponents = candidateURL.pathComponents
        return candidateComponents.starts(with: directoryComponents)
    }

    private func refreshMonitoredDirectoryURLs() {
        controller.directoryURLs = monitoredDirectoryURLs()
    }

    @objc private func volumesDidChange(_ notification: Notification) {
        refreshMonitoredDirectoryURLs()
    }
}
