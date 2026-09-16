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

        let defaults = AppConstants.sharedDefaults
        let actions = FinderActionStore.load(from: defaults)
        guard let action = actions.first(where: { $0.id == actionID }),
              let scriptURL = ScriptCatalog.scriptURL(for: action),
              FileManager.default.isExecutableFile(atPath: scriptURL.path)
        else {
            Diagnostics.log("Action is unavailable: id=\(actionID)", defaults: defaults)
            return
        }

        let process = Process()
        process.executableURL = scriptURL
        process.arguments = [path]
        if Diagnostics.isEnabled(in: defaults) {
            runWithDiagnostics(process, action: action, targetPath: path, defaults: defaults)
        } else {
            do {
                try process.run()
            } catch {
                Diagnostics.log("Failed to start \(action.name): \(error.localizedDescription)", defaults: defaults)
            }
        }
    }

    private static func runWithDiagnostics(
        _ process: Process,
        action: FinderActionDefinition,
        targetPath: String,
        defaults: UserDefaults
    ) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-actions-\(UUID().uuidString).log")
        _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        guard let outputHandle = try? FileHandle(forWritingTo: outputURL) else {
            Diagnostics.log("Could not create script output file for \(action.name)", defaults: defaults)
            return
        }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }

        process.standardOutput = outputHandle
        process.standardError = outputHandle
        do {
            Diagnostics.log("Starting script \(action.scriptFileName), target=\(targetPath)", defaults: defaults)
            try process.run()
            process.waitUntilExit()
            try outputHandle.synchronize()
            let output = (try? String(contentsOf: outputURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !output.isEmpty {
                logScriptOutput(output, actionName: action.name, defaults: defaults)
            }
            Diagnostics.log(
                "Script finished [\(action.name)]: status=\(process.terminationStatus), reason=\(process.terminationReason.rawValue)",
                defaults: defaults
            )
        } catch {
            Diagnostics.log("Failed to start \(action.name): \(error.localizedDescription)", defaults: defaults)
        }
    }

    private static func logScriptOutput(_ output: String, actionName: String, defaults: UserDefaults) {
        let chunkSize = 2_000
        var remaining = output[...]
        var part = 1
        while !remaining.isEmpty {
            let end = remaining.index(remaining.startIndex, offsetBy: chunkSize, limitedBy: remaining.endIndex)
                ?? remaining.endIndex
            Diagnostics.log(
                "Script output [\(actionName)] part \(part):\n\(remaining[..<end])",
                defaults: defaults
            )
            remaining = remaining[end...]
            part += 1
        }
    }
}
