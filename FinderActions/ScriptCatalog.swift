import AppKit
import Darwin
import Foundation

enum ScriptCatalog {
    struct ScanResult {
        let actions: [FinderActionDefinition]
        let ignoredFileCount: Int
    }

    static let actionsDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Finder Actions/Actions", isDirectory: true)

    static func prepareActionsDirectory() throws {
        let fileManager = FileManager.default
        if isSymbolicLink(actionsDirectoryURL) {
            throw CatalogError.unsafeActionsDirectory
        }
        try fileManager.createDirectory(at: actionsDirectoryURL, withIntermediateDirectories: true)
        guard (try? actionsDirectoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
              isOwnedByCurrentUser(actionsDirectoryURL)
        else {
            throw CatalogError.unsafeActionsDirectory
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: actionsDirectoryURL.path)
        guard let bundledDirectory = Bundle.main.resourceURL?.appendingPathComponent("Actions", isDirectory: true),
              let bundledScripts = try? fileManager.contentsOfDirectory(at: bundledDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return }

        for sourceURL in bundledScripts {
            let destinationURL = actionsDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
            let sourceData = try Data(contentsOf: sourceURL)
            let destinationIsSafe = isTrustedScriptFile(destinationURL)
            if !destinationIsSafe || (try? Data(contentsOf: destinationURL)) != sourceData {
                if itemExistsWithoutFollowingSymbolicLinks(destinationURL) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        }
    }

    static func availableActions() -> [FinderActionDefinition] {
        scan().actions
    }

    static func scan() -> ScanResult {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: actionsDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let actions = urls.compactMap { url -> FinderActionDefinition? in
            makeExecutableIfSafe(url)
            guard isTrustedScriptFile(url) else { return nil }
            return actionDefinition(at: url)
        }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return ScanResult(actions: actions, ignoredFileCount: urls.count - actions.count)
    }

    static func importScript(at sourceURL: URL) throws -> FinderActionDefinition {
        guard !isSymbolicLink(sourceURL), let action = actionDefinition(at: sourceURL) else {
            throw CatalogError.invalidScript
        }
        try prepareActionsDirectory()
        let destinationURL = actionsDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
        guard !itemExistsWithoutFollowingSymbolicLinks(destinationURL) else { throw CatalogError.duplicateFileName }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        guard isTrustedScriptFile(destinationURL) else { throw CatalogError.unsafeScript }
        return FinderActionDefinition(
            id: action.id,
            name: action.name,
            summaryZH: action.summaryZH,
            summaryEN: action.summaryEN,
            scriptFileName: action.scriptFileName
        )
    }

    static func scriptURL(for action: FinderActionDefinition) -> URL? {
        let url = actionsDirectoryURL.appendingPathComponent(action.scriptFileName).standardizedFileURL
        guard url.deletingLastPathComponent() == actionsDirectoryURL.standardizedFileURL else { return nil }
        return url
    }

    static func executableScriptURL(for action: FinderActionDefinition) -> URL? {
        guard let url = scriptURL(for: action),
              isTrustedScriptFile(url),
              FileManager.default.isExecutableFile(atPath: url.path)
        else { return nil }
        return url
    }

    static func revealActionsDirectory() {
        do {
            try prepareActionsDirectory()
        } catch {
            return
        }
        NSWorkspace.shared.open(actionsDirectoryURL)
    }

    private static func actionDefinition(at url: URL) -> FinderActionDefinition? {
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty, lines[0].hasPrefix("#!") else { return nil }
        let summaryZH = summary(from: lines, at: 1)
        let summaryEN = summary(from: lines, at: 2)
        let fileName = url.lastPathComponent
        let name = url.deletingPathExtension().lastPathComponent
        guard !name.isEmpty else { return nil }
        return FinderActionDefinition(
            id: "script.\(fileName)",
            name: name,
            summaryZH: summaryZH,
            summaryEN: summaryEN,
            scriptFileName: fileName
        )
    }

    private static func summary(from lines: [String], at index: Int) -> String {
        guard lines.indices.contains(index) else { return "" }
        let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("#"), !line.hasPrefix("#!") else { return "" }
        return String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isTrustedScriptFile(_ url: URL) -> Bool {
        guard !isSymbolicLink(url), isOwnedByCurrentUser(url),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o022 == 0
        else { return false }
        return true
    }

    private static func makeExecutableIfSafe(_ url: URL) {
        guard !isSymbolicLink(url), isOwnedByCurrentUser(url),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o022 == 0
        else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private static func isOwnedByCurrentUser(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let ownerID = attributes[.ownerAccountID] as? NSNumber
        else { return false }
        return ownerID.uint32Value == getuid()
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func itemExistsWithoutFollowingSymbolicLinks(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil || isSymbolicLink(url)
    }

    enum CatalogError: LocalizedError {
        case invalidScript
        case duplicateFileName
        case unsafeActionsDirectory
        case unsafeScript

        var errorDescription: String? {
            switch self {
            case .invalidScript:
                return "脚本第一行必须是 Shebang，例如 #!/bin/bash。"
            case .duplicateFileName:
                return "脚本文件夹中已有同名文件，请先改名再添加。"
            case .unsafeActionsDirectory:
                return "功能文件夹的安全设置不正确，无法读取。请重新创建该文件夹后再试。"
            case .unsafeScript:
                return "脚本的所有者或文件权限不安全，无法添加。"
            }
        }
    }
}
