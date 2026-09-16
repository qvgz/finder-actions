import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var alacrittyEnabled = AppConstants.sharedDefaults.object(
        forKey: AppConstants.alacrittyEnabledKey
    ) as? Bool ?? true
    @State private var codeEnabled = AppConstants.sharedDefaults.object(
        forKey: AppConstants.codeEnabledKey
    ) as? Bool ?? true

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
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500, height: 440)
    }

    private func save(_ value: Bool, forKey key: String) {
        AppConstants.sharedDefaults.set(value, forKey: key)
        CFPreferencesAppSynchronize(AppConstants.extensionBundleIdentifier as CFString)
    }

    private var legacyWorkflowsInstalled: Bool {
        let servicesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
        return ["Alacritty.workflow", "Code.workflow"].contains { name in
            FileManager.default.fileExists(atPath: servicesURL.appendingPathComponent(name).path)
        }
    }
}
