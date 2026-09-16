import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var finderActions = FinderActionStore.load(from: AppConstants.sharedDefaults)
    @State private var monitoredDirectories = SettingsView.initialMonitoredDirectories()
    @State private var directoriesNeedRestart = false
    @State private var troubleshootingExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    actionsSection
                    locationsSection
                    troubleshootingSection
                }
                .padding(28)
            }

            Divider()
            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
        }
        .frame(width: 680, height: 760)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
                .frame(width: 46, height: 46)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("设置 Finder 右键菜单")
                    .font(.title2.bold())
                Text("选择右键时显示的功能，以及可以使用这些功能的位置。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        settingsCard {
            sectionHeader(
                number: "1",
                title: "选择右键功能",
                description: "这些功能会按下方顺序显示在 Finder 右键菜单中。"
            )

            listContainer(height: 150) {
                if finderActions.isEmpty {
                    emptyState(
                        icon: "cursorarrow.rays",
                        title: "还没有右键功能",
                        message: "点击下方按钮添加 Alacritty、Code 或自定义脚本。"
                    )
                } else {
                    ForEach(finderActions) { action in
                        actionRow(action)
                    }
                }
            }

            HStack {
                Menu {
                    ForEach(availableApplications) { action in
                        Button {
                            addFinderAction(action)
                        } label: {
                            Label(addActionTitle(action), systemImage: "app")
                        }
                    }

                    if !availableApplications.isEmpty {
                        Divider()
                    }

                    Button(action: addScript) {
                        Label("添加自定义脚本（高级）…", systemImage: "scroll")
                    }
                } label: {
                    Label("添加右键功能", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
                Text("更改会自动保存")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var locationsSection: some View {
        settingsCard {
            sectionHeader(
                number: "2",
                title: "选择显示位置",
                description: "右键功能会出现在这些位置及其子文件夹中。推荐设置适合大多数用户。"
            )

            listContainer(height: 160) {
                if monitoredDirectories.isEmpty {
                    emptyState(
                        icon: "folder.badge.questionmark",
                        title: "没有选择显示位置",
                        message: "右键功能暂时不会出现在 Finder 中。"
                    )
                } else {
                    ForEach(monitoredDirectories, id: \.self) { path in
                        directoryRow(path)
                    }
                }
            }

            HStack {
                Button(action: addDirectories) {
                    Label("添加位置…", systemImage: "plus")
                }
                Button("使用推荐位置", action: restoreRecommendedDirectories)
                Spacer()
            }

            if directoriesNeedRestart {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("位置已更改")
                            .fontWeight(.medium)
                        Text("应用后，新位置才会出现在右键菜单中。Finder 会自动重新打开。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("应用位置更改", action: applyDirectoryChanges)
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private var troubleshootingSection: some View {
        DisclosureGroup(isExpanded: $troubleshootingExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text("如果右键菜单没有出现，请先确认 FinderActionsExtension 已启用。部分云盘或压缩软件也可能接管同一位置的右键菜单。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if legacyWorkflowsInstalled {
                    Label("检测到旧版 Alacritty/Code 服务，建议从“~/Library/Services”中移除。", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                Button("打开系统中的 Finder 扩展设置", action: openExtensionSettings)
            }
            .padding(.top, 10)
        } label: {
            Label("右键菜单没有出现？", systemImage: "questionmark.circle")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            Text(directoriesNeedRestart ? "还有位置更改尚未应用" : "所有更改均已保存")
                .font(.caption)
                .foregroundStyle(directoriesNeedRestart ? Color.orange : Color.secondary)
            Spacer()
            Button(directoriesNeedRestart ? "应用并完成" : "完成", action: finish)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var availableApplications: [FinderActionDefinition] {
        let enabledIDs = Set(finderActions.map(\.id))
        return FinderActionDefinition.supportedApplications.filter { !enabledIDs.contains($0.id) }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
            }
    }

    private func sectionHeader(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number)
                .font(.callout.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func listContainer<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, content: content)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .fontWeight(.medium)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 138)
        .padding(.horizontal, 20)
    }

    private func actionRow(_ action: FinderActionDefinition) -> some View {
        HStack(spacing: 11) {
            Image(systemName: action.kind == .script ? "scroll" : "app.fill")
                .font(.system(size: 17))
                .foregroundStyle(action.kind == .script ? Color.orange : Color.blue)
                .frame(width: 30, height: 30)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(action.name)
                    .fontWeight(.medium)
                Text(actionSubtitle(action))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if let scriptPath = action.scriptPath,
               !FileManager.default.isExecutableFile(atPath: scriptPath) {
                Text("无法使用")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                removeFinderAction(action)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("从右键菜单中移除")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
    }

    private func directoryRow(_ path: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: directoryIcon(path))
                .font(.system(size: 17))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(directoryName(path))
                    .fontWeight(.medium)
                Text(displayPath(path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }

            Spacer()

            if !FileManager.default.fileExists(atPath: path) {
                Text("当前不可用")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                removeDirectory(path)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("移除此位置")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
    }

    private func addActionTitle(_ action: FinderActionDefinition) -> String {
        "在 \(action.name) 中打开"
    }

    private func actionSubtitle(_ action: FinderActionDefinition) -> String {
        if let scriptPath = action.scriptPath {
            return "运行自定义脚本 · \(scriptPath)"
        }
        return "使用 \(action.name) 打开当前文件夹"
    }

    private func directoryName(_ path: String) -> String {
        switch path {
        case FileManager.default.homeDirectoryForCurrentUser.path: return "个人文件夹"
        case "/Applications": return "应用程序"
        case "/Volumes": return "外置磁盘"
        default: return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    private func directoryIcon(_ path: String) -> String {
        switch path {
        case FileManager.default.homeDirectoryForCurrentUser.path: return "house.fill"
        case "/Applications": return "app.dashed"
        case "/Volumes": return "externaldrive.fill"
        default: return "folder.fill"
        }
    }

    private func displayPath(_ path: String) -> String {
        NSString(string: path).abbreviatingWithTildeInPath
    }

    private func addFinderAction(_ action: FinderActionDefinition) {
        guard !finderActions.contains(where: { $0.id == action.id }) else { return }
        finderActions.append(action)
        saveFinderActions()
    }

    private func removeFinderAction(_ action: FinderActionDefinition) {
        finderActions.removeAll { $0.id == action.id }
        saveFinderActions()
    }

    private func addScript() {
        let panel = NSOpenPanel()
        panel.title = "选择要添加的脚本"
        panel.message = "脚本将在右键菜单中显示，并接收所选文件或文件夹的位置。"
        panel.prompt = "添加脚本"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        let path = selectedURL.standardizedFileURL.path
        guard FileManager.default.isExecutableFile(atPath: path) else {
            showAlert(
                title: "无法添加这个脚本",
                message: "脚本没有运行权限。请联系脚本提供者，或为它添加执行权限后重试。"
            )
            return
        }
        guard !finderActions.contains(where: { $0.scriptPath == path }) else {
            showAlert(title: "这个脚本已经添加", message: "无需重复添加，可以直接在 Finder 右键菜单中使用。")
            return
        }

        finderActions.append(.script(path: path))
        saveFinderActions()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func saveFinderActions() {
        FinderActionStore.save(finderActions, to: AppConstants.sharedDefaults)
        CFPreferencesAppSynchronize(AppConstants.extensionBundleIdentifier as CFString)
    }

    private func addDirectories() {
        let panel = NSOpenPanel()
        panel.title = "选择显示右键功能的位置"
        panel.message = "所选文件夹及其子文件夹都会显示 Finder Actions。"
        panel.prompt = "添加位置"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }

        let additions = panel.urls.map { $0.standardizedFileURL.path }
        let updatedDirectories = Array(Set(monitoredDirectories + additions)).sorted()
        guard updatedDirectories != monitoredDirectories else { return }
        monitoredDirectories = updatedDirectories
        saveMonitoredDirectories()
    }

    private func removeDirectory(_ path: String) {
        monitoredDirectories.removeAll { $0 == path }
        saveMonitoredDirectories()
    }

    private func restoreRecommendedDirectories() {
        let recommended = Self.recommendedDirectories()
        guard monitoredDirectories != recommended else { return }
        monitoredDirectories = recommended
        saveMonitoredDirectories()
    }

    private func saveMonitoredDirectories() {
        let defaults = AppConstants.sharedDefaults
        defaults.set(monitoredDirectories, forKey: AppConstants.monitoredDirectoriesKey)
        defaults.set(true, forKey: AppConstants.monitoredDirectoriesConfiguredKey)
        CFPreferencesAppSynchronize(AppConstants.extensionBundleIdentifier as CFString)
        directoriesNeedRestart = true
    }

    private func applyDirectoryChanges() {
        restartFinder()
        directoriesNeedRestart = false
    }

    private func finish() {
        if directoriesNeedRestart {
            restartFinder()
        }
        NSApp.terminate(nil)
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try? process.run()
    }

    private func openExtensionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func initialMonitoredDirectories() -> [String] {
        let defaults = AppConstants.sharedDefaults
        guard defaults.bool(forKey: AppConstants.monitoredDirectoriesConfiguredKey) else {
            return recommendedDirectories()
        }
        return defaults.stringArray(forKey: AppConstants.monitoredDirectoriesKey) ?? []
    }

    private static func recommendedDirectories() -> [String] {
        [FileManager.default.homeDirectoryForCurrentUser.path, "/Volumes", "/Applications"]
    }

    private var legacyWorkflowsInstalled: Bool {
        let servicesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
        return ["Alacritty.workflow", "Code.workflow"].contains { name in
            FileManager.default.fileExists(atPath: servicesURL.appendingPathComponent(name).path)
        }
    }
}
