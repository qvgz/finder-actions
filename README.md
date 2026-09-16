# Finder Actions

Finder Actions 是一个轻量的 macOS Finder Sync 扩展，可在 Finder 的空白区域、文件和文件夹右键菜单中显示自定义操作。

![示例图](example.png)

当前操作：

- **Alacritty**：在目标目录中打开 Alacritty。
- **Code**：使用 Visual Studio Code 打开目标目录。

右键文件时使用文件所在目录；右键文件夹时使用该文件夹；右键 Finder 空白区域时使用当前目录。宿主应用仅提供设置界面和执行启动请求，设置完成后可以退出。Finder Sync 扩展由 macOS 按需管理。

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

5. 在应用中选择需要显示的 Alacritty 和 Code 操作，并配置监控目录。
6. 打开“系统设置 → 通用 → 登录项与扩展 → Finder 扩展”，启用 **FinderActionsExtension**。
7. 如果菜单没有立即出现，运行：

   ```bash
   killall Finder
   ```

8. 如果此前安装过 `Alacritty.workflow` 或 `Code.workflow`，请从 `~/Library/Services` 移除。旧 workflow 的菜单与 Finder Actions 同名，但不具备 Finder 空白区域的完整覆盖能力。

宿主应用无需加入登录项，也无需保持运行，但不能删除或移出 `/Applications`，因为 Finder 扩展包含在应用包内。

## 配置监控目录

应用的“监控目录”区域支持：

- 一次选择一个或多个目录添加到监控列表。
- 单独移除不再需要的目录。
- 删除全部目录以完全停止显示 Finder 菜单。
- 恢复推荐设置：当前用户主目录、`/Volumes`、`/Applications`。
- 标记当前不存在或尚未挂载的目录。

修改目录后点击“重启 Finder”使配置生效。直接注册为监控根的目录在 Finder 收藏栏中可能显示 Finder Actions 图标，因此应优先添加需要覆盖目录的父目录。例如监控所有外置卷时添加 `/Volumes`，不要逐个添加 `/Volumes/pd`。

Finder Sync 的目录递归不会可靠跨越宗卷挂载点。配置 `/Volumes` 后，扩展会自动注册其下当前已挂载的宗卷，并在宗卷挂载、卸载或重命名时刷新，无需把每个宗卷单独加入列表。

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

在 GitHub 的 **Actions → Build Dev Release → Run workflow** 中可手动执行开发构建。该工作流始终检出 `master`，并覆盖固定的预发布版本 `dev`：

- Release 标签固定为 `dev`。
- 下载文件固定为 `Finder-Actions-dev.zip`。
- 应用版本为 `0.0.<GitHub run number>`。
- Release 说明列出从最近正式版本标签到当前 `master` 的提交。
- 每次执行都会删除旧的 `dev` Release 和标签，再基于当前 `master` 创建新的 `dev`。

## 本地开发

使用 Xcode 16.4 或更高版本打开 `FinderActions.xcodeproj`，选择 `FinderActions` scheme。默认 Bundle ID：

- 宿主应用：`io.github.qvgz.FinderActions`
- Finder 扩展：`io.github.qvgz.FinderActions.Extension`

如果 fork 本项目，建议同步修改两个 Bundle ID，以及宿主和扩展中的 `extensionBundleIdentifier` 常量。

## 架构说明

Finder Sync 扩展必须启用 App Sandbox。点击菜单项时，扩展通过 `finder-actions://` URL 唤醒宿主应用；宿主应用使用 Launch Services 启动目标程序后立即退出。这避免了从扩展沙盒直接运行外部可执行文件。

首次运行默认监控当前用户主目录、`/Applications` 和 `/Volumes`。用户保存自定义列表后，扩展严格使用该列表；空列表也是有效配置。外置卷可通过 `/Volumes` 的子目录递归覆盖，不必将单个卷注册为监控根目录。Alacritty 通过 `open` 启动，Code 通过 Visual Studio Code 应用包内置的 `bin/code` 启动。

配置写入扩展的用户偏好域。Alacritty/Code 开关通常无需重启 Finder；监控目录在扩展启动时注册，修改后需要重启 Finder。

## Finder Sync 限制

Finder Sync 不是通用的 Finder 菜单注入机制。macOS 对同一目录只允许一个 Finder Sync 扩展有效控制，而且 File Provider 的优先级更高。因此：

- Keka 等注册外层目录的 Finder 扩展可能阻止 Finder Actions 在本地目录和外置卷显示菜单。
- OneDrive、iCloud Drive 等 File Provider 管理的目录不会交给 Finder Actions。
- 开启 iCloud“桌面与文稿文件夹”后，`~/Desktop` 与 `~/Documents` 属于 File Provider 管理范围。

遇到菜单缺失时，在“系统设置 → 通用 → 登录项与扩展 → Finder 扩展”中暂时关闭 Keka、OneDrive 等其他 Finder 扩展，然后执行 `killall Finder`。如果目录由 iCloud/OneDrive File Provider 管理，只能关闭相应的文件夹同步功能或改用普通本地目录；Finder Actions 代码无法绕过这一系统优先级。

## License

[MIT](LICENSE)
