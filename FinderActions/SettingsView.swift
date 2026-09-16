import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum InterfaceLanguage: String, CaseIterable {
    case english
    case simplifiedChinese
}

struct SettingsView: View {
    @State private var finderActions: [FinderActionDefinition]
    @State private var availableActions: [FinderActionDefinition]
    @State private var actionsStatusMessage: String
    @State private var draggingActionID: String?
    @State private var interfaceLanguage: InterfaceLanguage
    @State private var languageSelectionPresented: Bool
    @State private var monitoredDirectories = SettingsView.initialMonitoredDirectories()
    @State private var directoriesNeedRestart = false
    @State private var troubleshootingExpanded = false
    @State private var diagnosticsEnabled = Diagnostics.isEnabled(in: AppConstants.sharedDefaults)

    init() {
        let defaults = AppConstants.sharedDefaults
        let savedLanguage = defaults.string(forKey: AppConstants.interfaceLanguageKey)
            .flatMap { InterfaceLanguage(rawValue: $0) }
        let initialLanguage = savedLanguage ?? .english
        let stored = FinderActionStore.load(from: defaults)
        let catalog: [FinderActionDefinition]
        let preparationError: Error?
        do {
            try ScriptCatalog.prepareActionsDirectory()
            catalog = ScriptCatalog.availableActions()
            preparationError = nil
        } catch {
            catalog = []
            preparationError = error
        }
        let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        let enabledActions: [FinderActionDefinition]
        if preparationError != nil {
            enabledActions = stored
        } else if defaults.data(forKey: FinderActionStore.actionsKey) == nil {
            enabledActions = catalog
        } else {
            enabledActions = stored.compactMap { catalogByID[$0.id] }
        }
        if preparationError == nil {
            FinderActionStore.save(enabledActions, to: defaults)
            CFPreferencesAppSynchronize(AppConstants.sharedPreferencesDomain as CFString)
        }
        _finderActions = State(initialValue: enabledActions)
        _availableActions = State(initialValue: catalog)
        _actionsStatusMessage = State(
            initialValue: preparationError == nil
                ? (initialLanguage == .english ? "Changes are saved automatically" : "更改会自动保存")
                : (initialLanguage == .english ? "The actions folder is unavailable" : "功能文件夹暂时无法读取")
        )
        _draggingActionID = State(initialValue: nil)
        _interfaceLanguage = State(initialValue: initialLanguage)
        _languageSelectionPresented = State(initialValue: savedLanguage == nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    actionsSection
                    locationsSection
                    troubleshootingSection
                    languageSection
                }
                .padding(28)
            }

            Divider()
            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
        }
        .frame(width: 680, height: 760)
        .sheet(isPresented: $languageSelectionPresented) {
            FirstLaunchLanguageView { language in
                setInterfaceLanguage(language)
                languageSelectionPresented = false
            }
            .interactiveDismissDisabled()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
                .frame(width: 46, height: 46)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(t("Set Up Finder Actions", "设置 Finder 右键菜单"))
                    .font(.title2.bold())
                Text(t(
                    "Choose which actions appear in Finder and where they are available.",
                    "选择右键时显示的功能，以及可以使用这些功能的位置。"
                ))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        settingsCard {
            sectionHeader(
                number: "1",
                title: t("Choose Finder Actions", "选择右键功能"),
                description: t(
                    "Actions appear in Finder's context menu in the order shown below.",
                    "这些功能会按下方顺序显示在 Finder 右键菜单中。"
                )
            )

            listContainer(height: 150) {
                if finderActions.isEmpty {
                    emptyState(
                        icon: "cursorarrow.rays",
                        title: t("No actions selected", "还没有右键功能"),
                        message: t(
                            "Use the button below to add an action to Finder.",
                            "点击下方按钮，选择要显示在右键菜单中的功能。"
                        )
                    )
                } else {
                    ForEach(finderActions) { action in
                        actionRow(action)
                    }
                }
            }

            HStack {
                Menu {
                    ForEach(disabledActions) { action in
                        Button {
                            addFinderAction(action)
                        } label: {
                            Label(action.name, systemImage: "plus")
                        }
                    }

                    if !disabledActions.isEmpty {
                        Divider()
                    }

                    Button(action: addScript) {
                        Label(t("Add Custom Script (Advanced)…", "添加自定义脚本（高级）…"), systemImage: "scroll")
                    }

                    Button(action: ScriptCatalog.revealActionsDirectory) {
                        Label(t("Open Scripts Folder", "打开脚本文件夹"), systemImage: "folder")
                    }

                    Button(action: refreshActions) {
                        Label(t("Refresh Action List", "刷新功能列表"), systemImage: "arrow.clockwise")
                    }
                } label: {
                    Label(t("Add Finder Action", "添加右键功能"), systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
                Text(actionsStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var locationsSection: some View {
        settingsCard {
            sectionHeader(
                number: "2",
                title: t("Choose Locations", "选择显示位置"),
                description: t(
                    "Actions appear in these locations and their subfolders. The recommended locations work for most people.",
                    "右键功能会出现在这些位置及其子文件夹中。推荐设置适合大多数用户。"
                )
            )

            listContainer(height: 160) {
                if monitoredDirectories.isEmpty {
                    emptyState(
                        icon: "folder.badge.questionmark",
                        title: t("No locations selected", "没有选择显示位置"),
                        message: t(
                            "Finder actions will not appear until you add a location.",
                            "右键功能暂时不会出现在 Finder 中。"
                        )
                    )
                } else {
                    ForEach(monitoredDirectories, id: \.self) { path in
                        directoryRow(path)
                    }
                }
            }

            HStack {
                Button(action: addDirectories) {
                    Label(t("Add Location…", "添加位置…"), systemImage: "plus")
                }
                Button(t("Use Recommended Locations", "使用推荐位置"), action: restoreRecommendedDirectories)
                Spacer()
            }

            if directoriesNeedRestart {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("Locations changed", "位置已更改"))
                            .fontWeight(.medium)
                        Text(t(
                            "Apply the changes to update the context menu. Finder will reopen automatically.",
                            "应用后，新位置才会出现在右键菜单中。Finder 会自动重新打开。"
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(t("Apply Location Changes", "应用位置更改"), action: applyDirectoryChanges)
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
                Text(t(
                    "Make sure FinderActionsExtension is enabled. Cloud-storage and archive apps may also take control of the same context menu.",
                    "如果右键菜单没有出现，请先确认 FinderActionsExtension 已启用。部分云盘或压缩软件也可能接管同一位置的右键菜单。"
                ))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if legacyWorkflowsInstalled {
                    Label(t(
                        "Legacy Alacritty/Code services were found. Remove them from ~/Library/Services to avoid duplicates.",
                        "检测到旧版 Alacritty/Code 服务，建议从“~/Library/Services”中移除。"
                    ), systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                Divider()

                Toggle(
                    t("Collect Diagnostic Information", "收集问题诊断信息"),
                    isOn: Binding(
                        get: { diagnosticsEnabled },
                        set: { setDiagnosticsEnabled($0) }
                    )
                )

                Text(t(
                    "Off by default. When enabled, diagnostic details are recorded to help investigate issues remotely. Logs may contain file paths.",
                    "默认关闭。开启后会记录右键菜单、所选位置和启动结果，方便开发者远程判断问题。日志可能包含文件路径。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if diagnosticsEnabled {
                    Button(t("Save Diagnostic Log to Desktop…", "将诊断日志保存到桌面…"), action: exportDiagnosticLog)
                }

                Button(t("Open Finder Extension Settings", "打开系统中的 Finder 扩展设置"), action: openExtensionSettings)
            }
            .padding(.top, 10)
        } label: {
            Label(t("Context menu not showing?", "右键菜单没有出现？"), systemImage: "questionmark.circle")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 4)
    }

    private var languageSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text(t(
                    "Choose the language used in Finder Actions.",
                    "选择 Finder Actions 使用的界面语言。"
                ))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { interfaceLanguage },
                    set: { setInterfaceLanguage($0) }
                )) {
                    Text("English").tag(InterfaceLanguage.english)
                    Text("中文（简体）").tag(InterfaceLanguage.simplifiedChinese)
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }
            .padding(.top, 10)
        } label: {
            Label("Language / 语言", systemImage: "globe")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            Text(directoriesNeedRestart
                ? t("Location changes have not been applied", "还有位置更改尚未应用")
                : t("All changes are saved", "所有更改均已保存"))
                .font(.caption)
                .foregroundStyle(directoriesNeedRestart ? Color.orange : Color.secondary)
            Spacer()
            Button(
                directoriesNeedRestart ? t("Apply and Done", "应用并完成") : t("Done", "完成"),
                action: finish
            )
                .keyboardShortcut(.defaultAction)
        }
    }

    private var disabledActions: [FinderActionDefinition] {
        let enabledIDs = Set(finderActions.map(\.id))
        return availableActions.filter { !enabledIDs.contains($0.id) }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        interfaceLanguage == .english ? english : chinese
    }

    private func actionSummary(_ action: FinderActionDefinition) -> String {
        let preferred = interfaceLanguage == .english ? action.summaryEN : action.summaryZH
        let fallback = interfaceLanguage == .english ? action.summaryZH : action.summaryEN
        return preferred.isEmpty ? fallback : preferred
    }

    private func setInterfaceLanguage(_ language: InterfaceLanguage) {
        interfaceLanguage = language
        let defaults = AppConstants.sharedDefaults
        defaults.set(language.rawValue, forKey: AppConstants.interfaceLanguageKey)
        CFPreferencesAppSynchronize(AppConstants.sharedPreferencesDomain as CFString)
        actionsStatusMessage = language == .english
            ? "Changes are saved automatically"
            : "更改会自动保存"
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
            Image(systemName: "scroll.fill")
                .font(.system(size: 17))
                .foregroundStyle(Color.blue)
                .frame(width: 30, height: 30)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(action.name)
                    .fontWeight(.medium)
                if !actionSummary(action).isEmpty {
                    Text(actionSummary(action))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if ScriptCatalog.executableScriptURL(for: action) == nil {
                Text(t("Unavailable", "无法使用"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
                .onDrag {
                    draggingActionID = action.id
                    return NSItemProvider(object: action.id as NSString)
                }
                .accessibilityLabel(t("Reorder \(action.name)", "调整 \(action.name) 的顺序"))
                .help(t("Drag to reorder the context menu", "拖动调整右键菜单顺序"))

            Button {
                removeFinderAction(action)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(t("Remove from the context menu", "从右键菜单中移除"))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .onDrop(
            of: [UTType.text],
            delegate: FinderActionDropDelegate(
                destinationID: action.id,
                actions: $finderActions,
                draggingActionID: $draggingActionID,
                save: saveFinderActions
            )
        )
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
                Text(t("Unavailable", "当前不可用"))
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
            .help(t("Remove this location", "移除此位置"))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
    }

    private func directoryName(_ path: String) -> String {
        switch path {
        case FileManager.default.homeDirectoryForCurrentUser.path: return t("Home", "个人文件夹")
        case "/Applications": return t("Applications", "应用程序")
        case "/Volumes": return t("External Volumes", "外置磁盘")
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

    private func refreshActions() {
        do {
            try ScriptCatalog.prepareActionsDirectory()
            let result = ScriptCatalog.scan()
            let catalogByID = Dictionary(uniqueKeysWithValues: result.actions.map { ($0.id, $0) })
            finderActions = finderActions.compactMap { catalogByID[$0.id] }
            availableActions = result.actions
            saveFinderActions()
            actionsStatusMessage = t(
                "Refreshed — \(result.actions.count) actions found",
                "已刷新，共找到 \(result.actions.count) 个功能"
            )

            if result.ignoredFileCount > 0 {
                showAlert(
                    title: t("Some files were skipped", "部分文件没有加入"),
                    message: t(
                        "\(result.ignoredFileCount) files did not meet the format or security requirements and were ignored. Other actions are ready to use.",
                        "有 \(result.ignoredFileCount) 个文件格式或安全设置不符合要求，已自动忽略。其他功能可以正常使用。"
                    )
                )
            }
        } catch {
            actionsStatusMessage = t("Refresh failed", "刷新失败")
            showAlert(
                title: t("Could Not Refresh Actions", "无法刷新功能列表"),
                message: localizedCatalogError(error)
            )
        }
    }

    private func addScript() {
        let panel = NSOpenPanel()
        panel.title = t("Choose a Script", "选择要添加的脚本")
        panel.message = t(
            "The filename becomes the menu title. The first line must be a shebang; lines two and three may contain Chinese and English descriptions.",
            "文件名会显示在右键菜单中。第一行必须是 Shebang，第二、三行可以填写中英文功能说明。"
        )
        panel.prompt = t("Add Script", "添加脚本")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        do {
            let action = try ScriptCatalog.importScript(at: selectedURL.standardizedFileURL)
            availableActions = ScriptCatalog.availableActions()
            finderActions.append(action)
            saveFinderActions()
        } catch {
            showAlert(title: t("Could Not Add Script", "无法添加这个脚本"), message: localizedCatalogError(error))
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func localizedCatalogError(_ error: Error) -> String {
        guard interfaceLanguage == .english,
              let catalogError = error as? ScriptCatalog.CatalogError
        else { return error.localizedDescription }

        switch catalogError {
        case .invalidScript:
            return "The first line of the script must be a shebang, such as #!/bin/bash."
        case .duplicateFileName:
            return "A script with this filename is already in the actions folder. Rename it and try again."
        case .unsafeActionsDirectory:
            return "The actions folder could not be opened safely. Recreate the folder and try again."
        case .unsafeScript:
            return "The script could not be added because its owner or file permissions are not safe."
        }
    }

    private func saveFinderActions() {
        FinderActionStore.save(finderActions, to: AppConstants.sharedDefaults)
        CFPreferencesAppSynchronize(AppConstants.sharedPreferencesDomain as CFString)
        Diagnostics.log(
            "Saved actions: \(finderActions.map(\.id))",
            defaults: AppConstants.sharedDefaults
        )
    }

    private func addDirectories() {
        let panel = NSOpenPanel()
        panel.title = t("Choose Where Actions Appear", "选择显示右键功能的位置")
        panel.message = t(
            "Finder Actions will appear in each selected folder and its subfolders.",
            "所选文件夹及其子文件夹都会显示 Finder Actions。"
        )
        panel.prompt = t("Add Location", "添加位置")
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
        CFPreferencesAppSynchronize(AppConstants.sharedPreferencesDomain as CFString)
        directoriesNeedRestart = true
        Diagnostics.log(
            "Saved display locations: \(monitoredDirectories)",
            defaults: AppConstants.sharedDefaults
        )
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

    private func setDiagnosticsEnabled(_ enabled: Bool) {
        let defaults = AppConstants.sharedDefaults
        if !enabled {
            Diagnostics.log("Diagnostics disabled by user", defaults: defaults)
        }
        defaults.set(enabled, forKey: Diagnostics.enabledKey)
        CFPreferencesAppSynchronize(AppConstants.sharedPreferencesDomain as CFString)
        diagnosticsEnabled = enabled

        if enabled {
            Diagnostics.log(
                "Diagnostics enabled; actions=\(finderActions.map(\.id)); locations=\(monitoredDirectories)",
                defaults: defaults
            )
        }
    }

    private func exportDiagnosticLog() {
        Diagnostics.log("Diagnostic log export requested", defaults: AppConstants.sharedDefaults)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "Finder-Actions-Diagnostics-\(formatter.string(from: Date())).log"
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent(fileName)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let header = """
        Finder Actions diagnostics
        Exported: \(Date())
        App version: \(version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Enabled actions: \(finderActions.map(\.id).joined(separator: ", "))
        Display locations: \(monitoredDirectories.joined(separator: ", "))

        """

        var openedFileHandle: FileHandle?
        defer { try? openedFileHandle?.close() }

        do {
            try Data(header.utf8).write(to: logURL, options: .atomic)
            let fileHandle = try FileHandle(forWritingTo: logURL)
            openedFileHandle = fileHandle
            try fileHandle.seekToEnd()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "show",
                "--last", "7d",
                "--style", "compact",
                "--predicate", "subsystem == \"\(Diagnostics.subsystem)\""
            ]
            process.standardOutput = fileHandle
            process.standardError = fileHandle
            try process.run()
            process.waitUntilExit()
            try fileHandle.close()
            openedFileHandle = nil

            guard process.terminationStatus == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }

            NSWorkspace.shared.activateFileViewerSelecting([logURL])
            showAlert(
                title: t("Diagnostic Log Saved", "诊断日志已保存"),
                message: t(
                    "The log was saved to your Desktop and is ready to share with the developer.",
                    "文件已保存到桌面，可以直接发送给开发者。"
                )
            )
        } catch {
            try? FileManager.default.removeItem(at: logURL)
            showAlert(
                title: t("Could Not Save Diagnostic Log", "无法保存诊断日志"),
                message: t(
                    "Make sure your Desktop is writable, then try again. Error: \(error.localizedDescription)",
                    "请确认桌面可以正常写入，然后重试。错误：\(error.localizedDescription)"
                )
            )
        }
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

private struct FirstLaunchLanguageView: View {
    let select: (InterfaceLanguage) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "globe")
                .font(.system(size: 42))
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("Choose your language")
                    .font(.title2.bold())
                Text("选择语言")
                    .font(.title3.bold())
                Text("Select the language used in Finder Actions.\n选择 Finder Actions 使用的界面语言。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 14) {
                languageButton(
                    title: "English",
                    subtitle: "Use English",
                    language: .english
                )
                languageButton(
                    title: "中文（简体）",
                    subtitle: "使用中文",
                    language: .simplifiedChinese
                )
            }
        }
        .padding(32)
        .frame(width: 480)
    }

    private func languageButton(
        title: String,
        subtitle: String,
        language: InterfaceLanguage
    ) -> some View {
        Button {
            select(language)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
    }
}

private struct FinderActionDropDelegate: DropDelegate {
    let destinationID: String
    @Binding var actions: [FinderActionDefinition]
    @Binding var draggingActionID: String?
    let save: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingActionID,
              draggingActionID != destinationID,
              let sourceIndex = actions.firstIndex(where: { $0.id == draggingActionID }),
              let destinationIndex = actions.firstIndex(where: { $0.id == destinationID })
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            actions.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggingActionID != nil else { return false }
        draggingActionID = nil
        save()
        return true
    }
}
