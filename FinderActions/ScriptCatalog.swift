import AppKit
import Foundation

enum ScriptCatalog {
    static let actionsDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Finder Actions/Actions", isDirectory: true)

    static func prepareActionsDirectory() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: actionsDirectoryURL, withIntermediateDirectories: true)
        guard let bundledDirectory = Bundle.main.resourceURL?.appendingPathComponent("Actions", isDirectory: true),
              let bundledScripts = try? fileManager.contentsOfDirectory(at: bundledDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return }

        for sourceURL in bundledScripts {
            let destinationURL = actionsDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
            let sourceData = try Data(contentsOf: sourceURL)
            if (try? Data(contentsOf: destinationURL)) != sourceData {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        }
    }

    static func availableActions() -> [FinderActionDefinition] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: actionsDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.compactMap(actionDefinition(at:)).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func importScript(at sourceURL: URL) throws -> FinderActionDefinition {
        guard let action = actionDefinition(at: sourceURL) else { throw CatalogError.invalidScript }
        try FileManager.default.createDirectory(at: actionsDirectoryURL, withIntermediateDirectories: true)
        let destinationURL = actionsDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else { throw CatalogError.duplicateFileName }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        return action
    }

    static func scriptURL(for action: FinderActionDefinition) -> URL? {
        let url = actionsDirectoryURL.appendingPathComponent(action.scriptFileName).standardizedFileURL
        guard url.deletingLastPathComponent() == actionsDirectoryURL.standardizedFileURL else { return nil }
        return url
    }

    static func revealActionsDirectory() {
        try? FileManager.default.createDirectory(at: actionsDirectoryURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(actionsDirectoryURL)
    }

    private static func actionDefinition(at url: URL) -> FinderActionDefinition? {
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2, lines[0].hasPrefix("#!") else { return nil }
        let summaryLine = lines[1].trimmingCharacters(in: .whitespaces)
        guard summaryLine.hasPrefix("#") else { return nil }
        let summary = String(summaryLine.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard !summary.isEmpty else { return nil }
        let fileName = url.lastPathComponent
        let name = url.deletingPathExtension().lastPathComponent
        guard !name.isEmpty else { return nil }
        return FinderActionDefinition(id: "script.\(fileName)", name: name, summary: summary, scriptFileName: fileName)
    }

    enum CatalogError: LocalizedError {
        case invalidScript
        case duplicateFileName

        var errorDescription: String? {
            switch self {
            case .invalidScript:
                return "脚本第一行必须是 Shebang（例如 #!/bin/bash），第二行必须是功能说明注释。"
            case .duplicateFileName:
                return "脚本文件夹中已有同名文件，请先改名再添加。"
            }
        }
    }
}
