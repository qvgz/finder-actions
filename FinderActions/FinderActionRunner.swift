import AppKit
import Foundation

enum FinderActionRunner {
    static func run(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "open",
              let action = components.queryItems?.first(where: { $0.name == "action" })?.value,
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value
        else { return }

        let directoryURL = URL(fileURLWithPath: path, isDirectory: true)

        switch action {
        case "alacritty":
            openAlacritty(at: directoryURL)
        case "code":
            openCode(at: directoryURL)
        default:
            break
        }
    }

    private static func openAlacritty(at directoryURL: URL) {
        let workspace = NSWorkspace.shared
        let applicationURL = workspace.urlForApplication(withBundleIdentifier: "org.alacritty")
            ?? URL(fileURLWithPath: "/Applications/Alacritty.app")
        guard FileManager.default.fileExists(atPath: applicationURL.path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-n",
            "-a", applicationURL.path,
            "--args", "--working-directory", directoryURL.path
        ]
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
}
