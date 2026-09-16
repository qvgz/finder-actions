# Finder Actions 开发与维护文档

本文档是 Finder Actions 的技术事实来源，面向维护者和参与开发的 AI。开始修改代码前应先阅读本文；架构、约束、行为或工作流发生变化时，必须同步更新本文。面向普通使用者的安装和使用说明只写入 `README.md`。

## 项目目标

Finder Actions 解决 macOS Finder 原生右键操作不易扩展的问题。它允许用户在 Finder 空白区域、文件和文件夹上执行可配置功能，并把具体功能下沉为脚本，从而做到：

- Swift 只负责 Finder 集成、配置、脚本发现与安全执行。
- 新增应用或新功能时，通常只需新增脚本，不需要修改 Swift 分支。
- 非技术用户通过图形界面启用功能和选择显示位置。
- 在开发者无法接触用户电脑时，可以依靠用户导出的诊断日志定位问题。

当前内置脚本是 Alacritty 和 Visual Studio Code，但项目定位不是“用某个程序打开”，未来可增加“新建文本”等任何适合 Finder 右键的功能。

## 产品和开发原则

- 配置界面优先符合非技术用户、普通办公用户的直觉。技术概念只能放在高级入口或开发文档中。
- Swift 保持通用，不为单个应用增加专用执行分支。
- 当前只有一个实际用户。除非需求明确提出，否则不做旧版本配置迁移和数据兼容。
- 当前只考虑 Ad-hoc 签名，不以正式 Developer ID 签名或 App Store 沙盒方案为前提。
- 保持修改范围小、可审查、可回滚；行为变化后同步更新本文和必要的用户文档。
- 不依赖宿主 App 常驻。设置完成后宿主可退出，Finder Sync 扩展由 macOS 管理。

## 系统结构

项目包含两个进程和一组共享源码：

```text
FinderActions.app
├── SwiftUI 设置界面
├── 脚本目录管理与安全检查
├── finder-actions:// 请求接收
└── 脚本执行及诊断输出收集

FinderActionsExtension.appex
├── 注册 Finder 监控根目录
├── 生成右键菜单
└── 将操作 ID 和目标路径发送给宿主 App

Shared/
├── FinderActionDefinition.swift
└── Diagnostics.swift
```

关键目录与文件：

- `FinderActions/AppDelegate.swift`：区分用户直接打开和 Finder 后台唤醒。
- `FinderActions/SettingsView.swift`：设置界面、配置保存、刷新和诊断日志导出。
- `FinderActions/ScriptCatalog.swift`：脚本安装、扫描、导入、安全检查和路径解析。
- `FinderActions/FinderActionRunner.swift`：解析 URL 请求并执行通用脚本。
- `FinderActionsExtension/FinderSync.swift`：Finder 菜单和监控目录实现。
- `Shared/FinderActionDefinition.swift`：宿主和扩展共享的操作模型及序列化。
- `Shared/Diagnostics.swift`：受用户开关控制的统一日志入口。
- `Actions/`：随 App 打包的默认脚本。

## 一次右键操作的完整流程

1. `FinderSync` 从共享偏好读取已启用操作并创建 `NSMenuItem`。
2. 菜单项使用数组位置写入 `NSMenuItem.tag`。不要依赖 `representedObject`，Finder 的跨进程菜单传递会丢失它，这曾导致菜单可见但点击无反应。
3. 点击菜单后，扩展优先读取第一个选中项目；没有选中项目时使用 Finder 当前窗口的 `targetedURL()`。
4. 扩展构造 `finder-actions://open?action=<id>&path=<absolute-path>`。
5. `NSWorkspace.OpenConfiguration.activates` 设置为 `false`，避免宿主 App 抢占 Finder 焦点造成明显的亮—暗—亮闪烁。
6. `AppDelegate` 以 accessory activation policy 启动。收到 URL 后调用 `FinderActionRunner`，完成后退出。
7. Runner 再次确认该操作仍处于启用状态，并在执行前重新进行脚本安全检查。
8. 脚本直接作为可执行文件启动，唯一参数是 Finder 目标的绝对路径。

用户直接启动 App 时没有 URL 请求，`AppDelegate` 在短暂等待后切换为普通前台应用并显示设置窗口。

## 脚本即功能

运行时脚本目录固定为：

```text
~/Library/Application Support/Finder Actions/Actions
```

脚本协议：

```bash
#!/bin/bash
# 面向用户的功能说明
```

- 文件名去掉最后一个扩展名后是菜单显示名。
- 第一行必须以 `#!` 开头。
- 第二行必须是非空注释，去掉 `#` 和首尾空白后作为 `summary`。
- 操作 ID 为 `script.<完整文件名>`。
- `$1` 是文件、文件夹或 Finder 当前目录的绝对路径。Swift 不替脚本转换目标类型。
- 脚本自行决定如何处理文件目标。例如内置 Alacritty、Code 脚本会把文件转换为其父目录。

`Actions/` 作为文件夹资源打包进 App。设置界面启动、导入脚本、打开脚本文件夹或主动刷新时会准备运行时目录。与内置脚本同名的运行时文件如果内容不同或安全检查失败，会被内置版本覆盖。因此，自定义脚本不应复用 `Alacritty.sh` 或 `Code.sh` 文件名。

用户导入脚本时，源文件被复制到运行时目录，不保留对原路径的引用。手动放入目录的安全脚本会在扫描时自动获得 `0755` 权限。新发现的脚本只进入“可添加”列表，不会自动启用；删除或失效的脚本在刷新时从已启用列表移除。

## 脚本轻量防护

本项目不实现脚本签名或哈希信任数据库。原因是脚本可编辑性是核心扩展方式，而有能力以当前用户身份任意写入该目录的攻击者通常还拥有许多其他持久化和代码执行路径。仍需防止有限文件写入能力被轻易升级为执行权限，因此保留以下低成本边界：

- Actions 目录必须是普通目录、不是符号链接，并由当前用户拥有。
- Actions 目录权限设置为 `0700`。
- 脚本必须是普通文件、不是符号链接，并由当前用户拥有。
- 脚本不能对 group 或 others 开放写权限。
- 安全但缺少执行位的脚本会被规范为 `0755`。
- 真正执行前重复检查所有者、文件类型、符号链接、写权限和可执行位。
- 导入界面提醒用户只添加可信脚本。

这是轻量防护，不是对已完全控制用户账户的攻击者提供安全隔离。检查与执行之间仍存在理论上的 TOCTOU 窗口；除非威胁模型改变，不为此引入复杂签名体系。

## 操作配置模型

共享模型为：

```swift
struct FinderActionDefinition: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let summary: String
    let scriptFileName: String
}
```

只保存文件名，不保存任意绝对脚本路径。Runner 使用 `standardizedFileURL` 确认最终路径仍直接位于 Actions 目录，防止通过文件名越界。

刷新目录时，以当前扫描结果为准更新已启用操作的名称和说明，保留原有启用顺序，移除已经不存在或不安全的操作。新脚本不会自动加入已启用列表。

## 共享偏好域约束

宿主和 Finder 扩展使用独立偏好域：

```text
io.github.qvgz.FinderActions.Shared
```

当前键：

| 键 | 类型 | 含义 |
| --- | --- | --- |
| `scriptActions` | JSON `Data` | 已启用操作的有序数组 |
| `monitoredDirectories` | `[String]` | 用户选择的监控目录绝对路径 |
| `monitoredDirectoriesConfigured` | `Bool` | 是否已经保存过目录配置；用于区分“首次运行”和“用户主动清空” |
| `diagnosticsEnabled` | `Bool` | 是否记录详细诊断日志 |

宿主 App 非沙盒，负责写入偏好。Finder 扩展必须启用 App Sandbox，通过 entitlement `com.apple.security.temporary-exception.shared-preference.read-only` 只读该偏好域。这是为了兼容 Ad-hoc 签名；不使用需要 Team ID 和 provisioning profile 的 App Group。

每次保存后调用 `CFPreferencesAppSynchronize`，扩展构建菜单前调用 `defaults.synchronize()`，降低两个进程看到旧配置的概率。新增或修改偏好键时必须同步更新宿主与扩展的 `AppConstants.swift`，以及本文档。

不要恢复旧的 `finderActions`、`alacrittyEnabled` 或 `codeEnabled` 迁移逻辑，除非后续需求明确要求兼容旧版本。

## Finder 监控目录

首次运行的默认目录：

- 当前用户主目录
- `/Applications`
- `/Volumes`

`monitoredDirectoriesConfigured == false` 时使用默认值；一旦用户保存过配置，就严格使用 `monitoredDirectories`。空数组是有效状态，表示完全不显示菜单。

Finder Sync 的目录递归不能可靠跨越挂载点。因此，若用户配置的根覆盖某个已挂载宗卷，扩展会把该宗卷也加入 `FIFinderSyncController.directoryURLs`。扩展监听挂载、卸载和宗卷改名通知并刷新注册目录。这是仅配置 `/Volumes` 也能覆盖 `/Volumes/pd` 的关键实现。

监控目录变更需要重启 Finder 才能稳定生效；设置界面对这类变更单独显示“应用位置更改”。操作列表更新通常不需要重启 Finder。

## Finder Sync 和 File Provider 限制

Finder Sync 不是任意目录上的通用菜单注入机制：

- macOS 对同一目录可能只让一个 Finder Sync 扩展有效控制。
- 外层目录上的其他扩展可能抢占子目录，例如 Keka。
- OneDrive、iCloud Drive 等 File Provider 管理的目录优先级更高，Finder Actions 无法绕过。
- 开启 iCloud“桌面与文稿文件夹”后，桌面和文稿也可能不再交给 Finder Sync。

Finder 会把扩展直接注册的监控根显示为扩展图标。跨宗卷稳定覆盖要求直接注册宗卷，而保留 Finder 收藏栏的原始动态图标要求它不是注册根，两者无法同时完全满足。用户层面的折中是创建指向宗卷的软链接并收藏软链接。

## 设置界面约束

设置界面按普通用户的任务顺序组织：

1. 选择“右键时可以做什么”。
2. 选择“这些功能在哪里出现”。
3. 排障和诊断放入折叠区域。

启用项显示在可滚动列表中，减号表示从右键菜单移除。添加菜单包含未启用操作、自定义脚本导入、打开脚本文件夹和刷新功能列表。技术错误必须转换为用户能采取行动的提示；不要把 POSIX 权限、偏好域、Finder Sync 生命周期等术语直接暴露给普通用户。

## 诊断日志

诊断默认关闭。`Diagnostics.log` 只有在 `diagnosticsEnabled` 为真时才写入 macOS Unified Logging：

- subsystem：`io.github.qvgz.FinderActions`
- category：`diagnostics`
- 日志按 `.public` 记录，以便用户导出后开发者能够看到路径和上下文。

诊断内容包括扩展启动、注册目录、菜单操作数组、点击目标、宿主 URL、脚本启动、退出状态以及 stdout/stderr。脚本输出按 2,000 字符分块，避免单条统一日志被截断。

诊断关闭时脚本异步启动，宿主不等待完成，以保持右键操作顺滑。诊断开启时宿主把 stdout 和 stderr 合并写入临时文件，等待脚本结束后记录输出和退出状态，再删除临时文件。因此调试模式可能让宿主存活更久，这是有意取舍。

设置界面使用 `/usr/bin/log show --last 7d` 导出相关 subsystem 到桌面，文件名为 `Finder-Actions-Diagnostics-<时间>.log`。日志可能包含用户路径和脚本输出，UI 必须继续提醒用户发送前检查并在排障后关闭诊断。

## 焦点和闪烁取舍

Finder 通过 URL Scheme 唤醒宿主是为了避免沙盒扩展直接运行外部程序。宿主以 accessory 模式启动，并且扩展使用 `configuration.activates = false`，这是当前降低 Finder 窗口焦点闪烁的实现。

完全消除由 Launch Services、目标应用激活或 macOS 窗口服务器造成的视觉变化未必可行。不要轻易改为激活宿主、显示隐藏窗口或让扩展直接执行脚本，这些方案分别会重新引入焦点闪烁、UI 干扰或沙盒限制。

## 构建与签名

本地开发使用 Xcode 16.4 或更高版本打开 `FinderActions.xcodeproj`，选择 `FinderActions` scheme。最低系统版本是 macOS 13。

标识：

- 宿主：`io.github.qvgz.FinderActions`
- 扩展：`io.github.qvgz.FinderActions.Extension`
- URL Scheme：`finder-actions`
- 共享偏好域：`io.github.qvgz.FinderActions.Shared`

当前 Debug、Release 和 CI 均使用手动 Ad-hoc 签名：`CODE_SIGN_IDENTITY="-"`、空 `DEVELOPMENT_TEAM`。修改 Bundle ID 时，必须同时检查 URL 注册、共享偏好域、扩展 entitlement、日志 subsystem 和文档。

建议验证顺序：

1. `bash -n Actions/*.sh`
2. `swiftc -frontend -parse` 分别检查宿主与扩展源文件
3. `plutil -lint` 检查工程、Info.plist 和 entitlements
4. `xcodebuild` 构建 FinderActions scheme
5. `codesign --verify --deep --strict` 检查 App
6. 安装后实际验证空白区域、文件、文件夹、外置宗卷和启停操作

## 发布工作流

正式发布由 `.github/workflows/release.yml` 负责：

- 仅响应 `vMAJOR.MINOR.PATCH` 标签。
- 标签去掉 `v` 后成为 App 版本。
- 构建 `arm64 + x86_64` 通用应用。
- 对 App 和扩展进行 Ad-hoc 签名并验证。
- 生成 zip 与 SHA-256 文件并创建同标签 Release。

开发发布由 `.github/workflows/dev.yml` 负责：

- `master` push 自动触发，也支持手动触发。
- 手动和自动流程始终检出当前 `master`，行为一致。
- 固定覆盖 `dev` 预发布和 `Finder-Actions-dev.zip`。
- App 版本是 `0.0.<GitHub run number>`。
- Release 说明列出最近正式版本标签到当前 `master` 的提交；没有正式标签时列出最近提交。

不要在没有明确需求时改变触发条件、签名方式、通用架构或固定 dev Release 的覆盖策略。

## 已确认的关键取舍

- 采用“脚本即功能”，牺牲每个应用的强类型 Swift 适配，换取无需改代码即可扩展。
- 只保存脚本文件名并集中管理，牺牲原地引用任意路径的自由，换取路径约束、刷新一致性和较简单的安全模型。
- 使用自定义共享偏好域和只读临时例外，换取 Ad-hoc 构建无需 App Group provisioning。
- Finder 扩展只生成菜单和转发请求，宿主执行脚本，换取扩展沙盒内行为简单可控。
- 使用 URL Scheme 唤醒短生命周期宿主，配合非激活打开降低焦点闪烁。
- `/Volumes` 之外还直接注册已挂载宗卷，换取跨挂载点菜单稳定性，但 Finder 可能显示扩展图标。
- 调试关闭时不等待脚本，优先交互速度；调试开启时等待并收集完整输出，优先可诊断性。
- 不做旧配置迁移，降低当前单用户阶段的维护成本。

## 修改时的文档责任

以下变化必须更新本文：

- 进程间调用链、URL 格式或 Finder 菜单映射方式。
- 脚本目录、格式、参数、安全规则或内置脚本更新策略。
- 偏好域、键名、数据结构、默认值或同步行为。
- Finder 监控目录算法和 File Provider 限制。
- UI 信息架构或面向普通用户的交互原则。
- 诊断收集范围、隐私提示或导出格式。
- Bundle ID、entitlement、签名、系统版本或发布工作流。
- 已确认取舍被推翻，或出现新的系统级限制。

用户可见的安装、操作或排障步骤发生变化时，还必须同步更新 `README.md`。
