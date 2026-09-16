import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var alacrittyEnabled = AppConstants.sharedDefaults.object(
        forKey: AppConstants.alacrittyEnabledKey
    ) as? Bool ?? true
    @State private var codeEnabled = AppConstants.sharedDefaults.object(
        forKey: AppConstants.codeEnabledKey
    ) as? Bool ?? true
    @State private var monitoredDirectories = SettingsView.initialMonitoredDirectories()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Finder Actions")
                .font(.title2.bold())

            Text("选择要显示在 Finder 右键菜单中的操作。设置完成后可以退出本应用。")
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Alacritty", isOn: $alacrittyEnabled)
                        .onChange(of: alacrittyEnabled) { value in
                            save(value, forKey: AppConstants.alacrittyEnabledKey)
                        }
                    Toggle("Code", isOn: $codeEnabled)
                        .onChange(of: codeEnabled) { value in
                            save(value, forKey: AppConstants.codeEnabledKey)
                        }
                }
                .padding(8)
            }

            GroupBox("监控目录") {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            if monitoredDirectories.isEmpty {
                                Text("未配置监控目录，Finder 中不会显示操作菜单。")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(6)
                            }
                            ForEach(monitoredDirectories, id: \.self) { path in
                                HStack(spacing: 8) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                    Text(path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .help(path)
                                    Spacer()
                                    if !FileManager.default.fileExists(atPath: path) {
                                        Text("不存在")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                    Button {
                                        removeDirectory(path)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("移除监控目录")
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    .frame(height: 130)

                    HStack {
                        Button("添加目录…", action: addDirectories)
                        Button("恢复推荐设置", action: restoreRecommendedDirectories)
                        Spacer()
                        Text("修改后需重启 Finder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("直接注册的监控根目录在 Finder 收藏栏中可能显示 Finder Actions 图标。优先添加需要覆盖目录的父目录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("Finder 兼容性") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Finder Sync 对同一目录只允许一个扩展有效控制。Keka、OneDrive、iCloud Desktop 与 Documents 可能阻止本扩展显示菜单。")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if legacyWorkflowsInstalled {
                        Text("检测到旧 Alacritty/Code workflow。请从 ~/Library/Services 移除，以免与 Finder Actions 菜单混淆。")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            HStack {
                Button("打开 Finder 扩展设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("重启 Finder", action: restartFinder)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620, height: 650)
    }

    private func save(_ value: Bool, forKey key: String) {
        AppConstants.sharedDefaults.set(value, forKey: key)
        CFPreferencesAppSynchronize(AppConstants.extensionBundleIdentifier as CFString)
    }

    private func addDirectories() {
        let panel = NSOpenPanel()
        panel.title = "选择 Finder Actions 监控目录"
        panel.prompt = "添加"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }

        let additions = panel.urls.map { $0.standardizedFileURL.path }
        monitoredDirectories = Array(Set(monitoredDirectories + additions)).sorted()
        saveMonitoredDirectories()
    }

    private func removeDirectory(_ path: String) {
        monitoredDirectories.removeAll { $0 == path }
        saveMonitoredDirectories()
    }

    private func restoreRecommendedDirectories() {
        monitoredDirectories = Self.recommendedDirectories()
        saveMonitoredDirectories()
    }

    private func saveMonitoredDirectories() {
        let defaults = AppConstants.sharedDefaults
        defaults.set(monitoredDirectories, forKey: AppConstants.monitoredDirectoriesKey)
        defaults.set(true, forKey: AppConstants.monitoredDirectoriesConfiguredKey)
        CFPreferencesAppSynchronize(AppConstants.extensionBundleIdentifier as CFString)
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try? process.run()
    }

    private static func initialMonitoredDirectories() -> [String] {
        let defaults = AppConstants.sharedDefaults
        guard defaults.bool(forKey: AppConstants.monitoredDirectoriesConfiguredKey) else {
            return recommendedDirectories()
        }
        return defaults.stringArray(forKey: AppConstants.monitoredDirectoriesKey) ?? []
    }

    private static func recommendedDirectories() -> [String] {
        [
            FileManager.default.homeDirectoryForCurrentUser.path,
            "/Volumes",
            "/Applications"
        ]
    }

    private var legacyWorkflowsInstalled: Bool {
        let servicesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
        return ["Alacritty.workflow", "Code.workflow"].contains { name in
            FileManager.default.fileExists(atPath: servicesURL.appendingPathComponent(name).path)
        }
    }
}
