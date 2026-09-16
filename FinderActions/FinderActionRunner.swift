import AppKit
import Foundation

enum FinderActionRunner {
    static func run(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "open",
              let actionID = components.queryItems?.first(where: { $0.name == "action" })?.value,
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value
        else {
            Diagnostics.log("Rejected malformed action URL", defaults: AppConstants.sharedDefaults)
            return
        }

        let actions = FinderActionStore.load(from: AppConstants.sharedDefaults)
        Diagnostics.log(
            "Running action id=\(actionID), target=\(path), configured=\(actions.map(\.id))",
            defaults: AppConstants.sharedDefaults
        )
        guard let action = actions.first(where: { $0.id == actionID }) else {
            Diagnostics.log("Action id is not configured: \(actionID)", defaults: AppConstants.sharedDefaults)
            return
        }

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
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            Diagnostics.log("Alacritty application was not found", defaults: AppConstants.sharedDefaults)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", applicationURL.path, "--args", "--working-directory", directoryURL.path]
        run(process, description: "Alacritty")
    }

    private static func openCode(at directoryURL: URL) {
        let workspace = NSWorkspace.shared
        let applicationURL = workspace.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
            ?? URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            Diagnostics.log("Visual Studio Code application was not found", defaults: AppConstants.sharedDefaults)
            return
        }

        let codeCLI = applicationURL.appendingPathComponent("Contents/Resources/app/bin/code")
        guard FileManager.default.isExecutableFile(atPath: codeCLI.path) else {
            Diagnostics.log("Code command is missing or not executable: \(codeCLI.path)", defaults: AppConstants.sharedDefaults)
            return
        }

        let process = Process()
        process.executableURL = codeCLI
        process.arguments = [directoryURL.path]
        run(process, description: "Code")
    }

    private static func runScript(_ action: FinderActionDefinition, targetURL: URL) {
        guard let scriptPath = action.scriptPath,
              FileManager.default.isExecutableFile(atPath: scriptPath)
        else {
            Diagnostics.log("Script is missing or not executable: \(action.scriptPath ?? "nil")", defaults: AppConstants.sharedDefaults)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.arguments = [targetURL.path]
        run(process, description: "script \(scriptPath)")
    }

    private static func run(_ process: Process, description: String) {
        do {
            try process.run()
            Diagnostics.log("Started \(description), pid=\(process.processIdentifier)", defaults: AppConstants.sharedDefaults)
        } catch {
            Diagnostics.log(
                "Failed to start \(description): \(error.localizedDescription)",
                defaults: AppConstants.sharedDefaults
            )
        }
    }
}
