import AppKit
import Foundation

enum FinderActionRunner {
    static func run(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "open",
              let actionID = components.queryItems?.first(where: { $0.name == "action" })?.value,
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value
        else { return }

        let actions = FinderActionStore.load(from: AppConstants.sharedDefaults)
        guard let action = actions.first(where: { $0.id == actionID }) else { return }

        let targetURL = URL(fileURLWithPath: path)
        switch action.kind {
        case .builtIn:
            let directoryURL = directoryURL(for: targetURL)
            switch action.builtInIdentifier {
            case "alacritty": openAlacritty(at: directoryURL)
            case "code": openCode(at: directoryURL)
            default: break
            }
        case .script:
            runScript(action, targetURL: targetURL)
        }
    }

    private static func directoryURL(for targetURL: URL) -> URL {
        let resourceValues = try? targetURL.resourceValues(forKeys: [.isDirectoryKey])
        if targetURL.hasDirectoryPath || resourceValues?.isDirectory == true {
            return targetURL
        }
        return targetURL.deletingLastPathComponent()
    }

    private static func openAlacritty(at directoryURL: URL) {
        let workspace = NSWorkspace.shared
        let applicationURL = workspace.urlForApplication(withBundleIdentifier: "org.alacritty")
            ?? URL(fileURLWithPath: "/Applications/Alacritty.app")
        guard FileManager.default.fileExists(atPath: applicationURL.path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", applicationURL.path, "--args", "--working-directory", directoryURL.path]
        try? process.run()
    }

    private static func openCode(at directoryURL: URL) {
        let workspace = NSWorkspace.shared
        let applicationURL = workspace.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
            ?? URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        guard FileManager.default.fileExists(atPath: applicationURL.path) else { return }

        let codeCLI = applicationURL.appendingPathComponent("Contents/Resources/app/bin/code")
        guard FileManager.default.isExecutableFile(atPath: codeCLI.path) else { return }

        let process = Process()
        process.executableURL = codeCLI
        process.arguments = [directoryURL.path]
        try? process.run()
    }

    private static func runScript(_ action: FinderActionDefinition, targetURL: URL) {
        guard let scriptPath = action.scriptPath,
              FileManager.default.isExecutableFile(atPath: scriptPath)
        else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.arguments = [targetURL.path]
        try? process.run()
    }
}
