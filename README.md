# Finder Actions

Finder Actions 是一个轻量的 macOS Finder Sync 扩展，可在 Finder 的空白区域、文件和文件夹右键菜单中显示自定义操作。

![示例图](example.png)

内置操作：

- **Alacritty**：在目标目录中打开 Alacritty。
- **Code**：使用 Visual Studio Code 打开目标目录。
- **自定义脚本**：执行用户选择的可执行脚本，并将右键目标的绝对路径作为第一个参数。

使用 Alacritty 或 Code 时，右键文件会打开文件所在目录，右键文件夹会打开该文件夹，右键 Finder 空白区域会打开当前目录。使用自定义脚本时，文件、文件夹或当前目录自身的绝对路径会直接传给脚本。宿主应用仅提供设置界面和执行启动请求，设置完成后可以退出。Finder Sync 扩展由 macOS 按需管理。

## 系统要求

- macOS 13 Ventura 或更高版本。
- Alacritty 和 Visual Studio Code 默认安装在 `/Applications`，也支持由 Launch Services 找到的其他安装位置。

发布包使用 Ad-hoc 签名，不需要在本机安装 Xcode。

## 安装

1. 从 [Releases](../../releases) 下载对应版本的 `Finder-Actions-<version>.zip`。
2. 解压，将 `Finder Actions.app` 移动到 `/Applications`。
3. 在终端移除下载隔离属性：

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Finder Actions.app"
   ```

4. 打开一次应用：

   ```bash
   open "/Applications/Finder Actions.app"
   ```

5. 在应用中选择需要显示的右键功能和显示位置。
6. 打开“系统设置 → 通用 → 登录项与扩展 → Finder 扩展”，启用 **FinderActionsExtension**。
7. 如果菜单没有立即出现，运行：

   ```bash
   killall Finder
   ```

8. 如果此前安装过 `Alacritty.workflow` 或 `Code.workflow`，请从 `~/Library/Services` 移除。旧 workflow 的菜单与 Finder Actions 同名，但不具备 Finder 空白区域的完整覆盖能力。

宿主应用无需加入登录项，也无需保持运行，但不能删除或移出 `/Applications`，因为 Finder 扩展包含在应用包内。

## 配置右键操作

配置界面按两个步骤组织：先选择“右键时可以做什么”，再选择“右键功能出现在哪里”。右键功能列表显示当前已启用的操作。点击“添加右键功能”可以启用尚未添加的 Alacritty 或 Code，也可以在高级选项中选择自定义脚本；点击列表右侧的减号可移除操作。操作列表的变化会自动保存，并在下次打开 Finder 右键菜单时生效。

自定义脚本会以当前用户权限运行，因此只应添加可信脚本。脚本必须包含正确的 shebang 并具有可执行权限，例如：

```bash
chmod +x /path/to/script.sh
```

执行脚本时只追加一个参数：右键文件时传入文件绝对路径，右键文件夹时传入文件夹绝对路径，右键空白区域时传入当前目录绝对路径。脚本被移动、删除或失去可执行权限后，设置界面会显示“不可执行”，且 Finder 不会运行它。

## 配置显示位置

应用的“选择显示位置”区域支持：

- 一次选择一个或多个目录添加到监控列表。
- 单独移除不再需要的目录。
- 删除全部目录以完全停止显示 Finder 菜单。
- 恢复推荐设置：当前用户主目录、`/Volumes`、`/Applications`。
- 标记当前不可用或尚未连接的位置。

修改显示位置后，界面会明确提示“位置已更改”。点击“应用位置更改”或底部的“应用并完成”即可生效，Finder 会自动重新打开。直接注册的显示位置在 Finder 收藏栏中可能显示 Finder Actions 图标，因此应优先添加需要覆盖目录的父目录。例如覆盖所有外置卷时添加 `/Volumes`，不要逐个添加 `/Volumes/pd`。

Finder Sync 的目录递归不会可靠跨越宗卷挂载点。配置 `/Volumes` 后，扩展会自动注册其下当前已挂载的宗卷，并在宗卷挂载、卸载或重命名时刷新，无需把每个宗卷单独加入列表。

Finder 会为扩展直接注册的监控根显示 Finder Actions 图标。因此，无法同时保证跨宗卷右键功能稳定，又让 Finder 将宗卷当作非监控根并完全保留原始动态图标。如果希望收藏栏使用普通图标，可以创建指向宗卷的软链接，再把软链接拖入 Finder 收藏栏，例如：

```bash
ln -s /Volumes/pd ~/pd-link
```

通过该收藏项进入的仍是 `/Volumes/pd`，Alacritty 和 Code 右键功能不受影响；创建前请确认 `~/pd-link` 尚不存在，也可以换用其他链接名称或位置。

## 从标签发布

GitHub Actions 只响应 `vMAJOR.MINOR.PATCH` 形式的标签，例如：

```bash
git tag v1.0.0
git push origin v1.0.0
```

工作流会：

1. 校验标签格式。
2. 将标签去掉 `v` 后作为 `CFBundleShortVersionString`，例如 `v1.2.3` 对应应用版本 `1.2.3`。
3. 使用 GitHub 的 macOS runner 构建包含 `arm64` 和 `x86_64` 的通用应用。
4. 对应用和 Finder 扩展进行 Ad-hoc 签名并验证签名。
5. 生成 zip 和 SHA-256 校验文件。
6. 上传 Actions Artifact 并创建同标签的 GitHub Release。

正式发布工作流不会由分支推送、Pull Request 或手动操作触发；只有符合格式的版本标签会触发正式发布。

## Dev 发布

每次向 `master` 推送提交时会自动执行开发构建，也可以在 GitHub 的 **Actions → Build Dev Release → Run workflow** 中手动执行。两种触发方式使用相同流程：始终检出 `master`，并覆盖固定的预发布版本 `dev`。

- Release 标签固定为 `dev`。
- 下载文件固定为 `Finder-Actions-dev.zip`。
- 应用版本为 `0.0.<GitHub run number>`。
- Release 说明列出从最近正式版本标签到当前 `master` 的提交。
- 每次执行都会删除旧的 `dev` Release 和标签，再基于当前 `master` 创建新的 `dev`。

## 本地开发

使用 Xcode 16.4 或更高版本打开 `FinderActions.xcodeproj`，选择 `FinderActions` scheme。默认 Bundle ID：

- 宿主应用：`io.github.qvgz.FinderActions`
- Finder 扩展：`io.github.qvgz.FinderActions.Extension`

如果 fork 本项目，建议同步修改两个 Bundle ID、共享偏好域及对应的沙盒例外 entitlement。

## 架构说明

Finder Sync 扩展必须启用 App Sandbox。点击菜单项时，扩展通过不激活目标进程的 `finder-actions://` URL 在后台唤醒宿主应用；宿主应用以 accessory 模式使用 Launch Services 启动目标程序后立即退出，避免在 Finder 与目标程序之间短暂抢占焦点。这也避免了从扩展沙盒直接运行外部可执行文件。用户直接打开宿主应用时，它才切换为普通前台应用并显示设置窗口。

首次运行默认监控当前用户主目录、`/Applications` 和 `/Volumes`。用户保存自定义列表后，扩展严格使用该列表；空列表也是有效配置。外置卷可通过 `/Volumes` 的子目录递归覆盖，不必将单个卷注册为监控根目录。Alacritty 通过 `open` 启动，Code 通过 Visual Studio Code 应用包内置的 `bin/code` 启动。

操作和监控目录配置写入独立的共享偏好域 `io.github.qvgz.FinderActions.Shared`。非沙盒宿主负责写入，Finder 扩展通过最小范围的 `shared-preference.read-only` 沙盒例外只读访问；此方案兼容 Ad-hoc 签名，不依赖 App Group、Team ID 或 provisioning profile。宿主应用首次启动时会迁移旧偏好。宿主与扩展共同使用 `Shared/FinderActionDefinition.swift` 中的操作模型和存储格式；新增内置应用时只需添加操作定义及对应执行适配器。操作列表通常无需重启 Finder；监控目录在扩展启动时注册，修改后需要重启 Finder。

## Finder Sync 限制

Finder Sync 不是通用的 Finder 菜单注入机制。macOS 对同一目录只允许一个 Finder Sync 扩展有效控制，而且 File Provider 的优先级更高。因此：

- Keka 等注册外层目录的 Finder 扩展可能阻止 Finder Actions 在本地目录和外置卷显示菜单。
- OneDrive、iCloud Drive 等 File Provider 管理的目录不会交给 Finder Actions。
- 开启 iCloud“桌面与文稿文件夹”后，`~/Desktop` 与 `~/Documents` 属于 File Provider 管理范围。

遇到菜单缺失时，在“系统设置 → 通用 → 登录项与扩展 → Finder 扩展”中暂时关闭 Keka、OneDrive 等其他 Finder 扩展，然后执行 `killall Finder`。如果目录由 iCloud/OneDrive File Provider 管理，只能关闭相应的文件夹同步功能或改用普通本地目录；Finder Actions 代码无法绕过这一系统优先级。

配置界面的“右键菜单没有出现？”区域提供“收集问题诊断信息”开关，默认关闭。开启后，Finder Actions 会通过 macOS 统一日志记录配置读取、菜单生成、右键目标和程序启动结果；日志可能包含本机文件路径。复现问题后点击“将诊断日志保存到桌面…”，即可生成 `Finder-Actions-Diagnostics-<时间>.log` 并发送给开发者。发送前可以先用文本编辑器检查内容，问题排查完成后建议关闭诊断开关。

## License

[MIT](LICENSE)
