import AppKit
import Darwin
import FinderSync

final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()

    override init() {
        super.init()
        refreshMonitoredDirectoryURLs()
        Diagnostics.log("Finder extension started", defaults: AppConstants.sharedDefaults)

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
        let defaults = AppConstants.sharedDefaults
        defaults.synchronize()
        let actions = FinderActionStore.load(from: defaults)
        Diagnostics.log(
            "Building menu kind=\(menuKind.rawValue), actions=\(actions.map(\.id))",
            defaults: defaults
        )
        for (index, action) in actions.enumerated() {
            let menuItem = menu.addItem(
                withTitle: action.name,
                action: #selector(runFinderAction(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = index
        }

        return menu.items.isEmpty ? nil : menu
    }

    @objc private func runFinderAction(_ sender: NSMenuItem) {
        let defaults = AppConstants.sharedDefaults
        defaults.synchronize()
        let actions = FinderActionStore.load(from: defaults)
        guard actions.indices.contains(sender.tag) else {
            Diagnostics.log(
                "Menu item has invalid tag=\(sender.tag), title=\(sender.title), actions=\(actions.map(\.id))",
                defaults: defaults
            )
            return
        }
        let actionID = actions[sender.tag].id
        guard let selectedTargetURL = targetURL() else {
            Diagnostics.log("Finder did not provide a target URL", defaults: defaults)
            return
        }

        Diagnostics.log(
            "Menu action selected tag=\(sender.tag), id=\(actionID), target=\(selectedTargetURL.path)",
            defaults: defaults
        )

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
            NSWorkspace.shared.open(url, configuration: configuration) { _, error in
                if let error {
                    Diagnostics.log(
                        "Failed to open host URL: \(error.localizedDescription)",
                        defaults: AppConstants.sharedDefaults
                    )
                }
            }
        }
    }

    private func targetURL() -> URL? {
        if let selectedURL = controller.selectedItemURLs()?.first {
            return selectedURL
        }

        return controller.targetedURL()
    }

    private func monitoredDirectoryURLs() -> Set<URL> {
        let defaults = AppConstants.sharedDefaults
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
        let urls = monitoredDirectoryURLs()
        controller.directoryURLs = urls
        Diagnostics.log(
            "Registered monitored directories: \(urls.map(\.path).sorted())",
            defaults: AppConstants.sharedDefaults
        )
    }

    @objc private func volumesDidChange(_ notification: Notification) {
        refreshMonitoredDirectoryURLs()
    }
}
