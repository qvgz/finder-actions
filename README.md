# Finder Actions

Finder Actions 是一个轻量的 macOS Finder Sync 扩展，可在 Finder 的空白区域、文件和文件夹右键菜单中显示自定义操作。

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

5. 在应用中选择需要显示的 Alacritty 和 Code 操作。
6. 打开“系统设置 → 通用 → 登录项与扩展 → Finder 扩展”，启用 **FinderActionsExtension**。
7. 如果菜单没有立即出现，运行：

   ```bash
   killall Finder
   ```

宿主应用无需加入登录项，也无需保持运行，但不能删除或移出 `/Applications`，因为 Finder 扩展包含在应用包内。

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

分支推送、Pull Request 和手动操作不会触发编译发布。

## 本地开发

使用 Xcode 16.4 或更高版本打开 `FinderActions.xcodeproj`，选择 `FinderActions` scheme。默认 Bundle ID：

- 宿主应用：`io.github.qvgz.FinderActions`
- Finder 扩展：`io.github.qvgz.FinderActions.Extension`

如果 fork 本项目，建议同步修改两个 Bundle ID，以及宿主和扩展中的 `extensionBundleIdentifier` 常量。

## 架构说明

Finder Sync 扩展必须启用 App Sandbox。点击菜单项时，扩展通过 `finder-actions://` URL 唤醒宿主应用；宿主应用使用 Launch Services 启动目标程序后立即退出。这避免了从扩展沙盒直接运行外部可执行文件。

配置写入扩展的用户偏好域，扩展每次构建右键菜单时读取，因此切换开关通常无需重启 Finder。

## License

[MIT](LICENSE)
