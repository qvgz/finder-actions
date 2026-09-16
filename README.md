# Finder Actions

English | [简体中文](README-zh.md)

Finder Actions adds useful context-menu actions to macOS Finder. Right-click the background of a Finder window, a file, or a folder to open that location in Alacritty or Visual Studio Code, or to run your own scripts.

![Finder Actions](example.png)

Built-in actions include:

- **Alacritty** — open the current folder in Alacritty.
- **Code** — open the current folder in Visual Studio Code.
- **Custom scripts** — add your own Finder actions without modifying the app.

Finder Actions requires macOS 13 Ventura or later.

## Installation

1. Download the latest `Finder-Actions-<version>.zip` from [Releases](../../releases).
2. Unzip it and move `Finder Actions.app` to `/Applications`.
3. Open Terminal and remove the download quarantine attribute:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Finder Actions.app"
   ```

4. Open Finder Actions once.
5. Go to **System Settings → General → Login Items & Extensions → Finder Extensions**, then enable **FinderActionsExtension**.
6. Return to Finder. If the actions do not appear immediately, restart Finder:

   ```bash
   killall Finder
   ```

Finder Actions does not need to run at login or remain open. Keep the app in `/Applications`; moving or deleting it will also remove its Finder extension.

## Choose Your Finder Actions

Open Finder Actions, then:

1. Review the actions currently shown in the **Choose Finder Actions** list.
2. Click **Add Finder Action** to enable another available action.
3. Drag the three-line handle beside an action to change its position in Finder's context menu.
4. Click the minus button to remove an action from the context menu.

Changes, including action order, are saved automatically and normally do not require restarting Finder. Removing an action does not delete its script, so you can add it again later.

## Choose Where Actions Appear

Use **Choose Locations** to control where the context-menu actions are available:

- Click **Add Location** to select one or more folders.
- Click the minus button beside a location to stop monitoring it.
- Click **Use Recommended Locations** to restore your home folder, external volumes, and the Applications folder.

Actions also appear in subfolders of each selected location. After changing locations, click **Apply Location Changes** or **Apply and Done**. Finder Actions will restart Finder for you.

For external drives, add `/Volumes` instead of adding each individual volume. This also covers drives mounted in the future.

## How Targets Are Passed to Actions

- Right-click a folder: the script receives that folder's absolute path.
- Right-click a file: the script receives that file's absolute path.
- Right-click the background of a Finder window: the script receives the current folder's absolute path.

The built-in Alacritty and Code actions automatically use the containing folder when the selected target is a file.

## Add a Custom Script

Only add scripts from sources you trust.

Choose **Add Finder Action → Add Custom Script**. Finder Actions copies the script into its managed actions folder and makes it executable. A script must begin with this structure:

```bash
#!/bin/bash
# Describe what this action does for the user
```

- The filename without its final extension becomes the context-menu title. For example, `New Text.sh` appears as “New Text.”
- The first line must be a shebang.
- The second line must be a comment describing the action.
- The Finder target's absolute path is passed as the first argument, `$1`.

You can also choose **Add Finder Action → Open Scripts Folder** to manage scripts directly. After adding or editing a script there, choose **Refresh Action List** from the same menu. Finder Actions automatically ignores files that do not meet its format or security requirements.

## Troubleshooting

### The context-menu actions do not appear

Check the following:

1. **FinderActionsExtension** is enabled in System Settings.
2. The current folder is inside one of the locations configured in Finder Actions.
3. Another Finder extension, such as Keka, is not taking control of the same location.
4. The folder is not managed by a cloud provider such as iCloud Drive or OneDrive.

macOS may give another Finder extension or File Provider priority. Temporarily disable competing extensions and run `killall Finder` to try again. Finder Actions cannot force its menu into a location fully managed by a File Provider.

If you previously installed `Alacritty.workflow` or `Code.workflow`, remove them from `~/Library/Services` to avoid duplicate legacy actions.

### An external drive has a Finder Actions icon in the sidebar

Finder displays the extension's icon for locations registered directly as monitoring roots. Reliable context-menu support across mounted volumes and complete preservation of each volume's original dynamic icon cannot both be guaranteed.

To keep a standard sidebar icon, create a symbolic link to the volume and add the link to Finder's sidebar instead:

```bash
ln -s /Volumes/pd ~/pd-link
```

Replace `pd` with the actual volume name and make sure the destination link does not already exist.

### Export a diagnostic log

Expand **Context menu not showing?** at the bottom of Finder Actions and enable **Collect Diagnostic Information**. Reproduce the problem once, then click **Save Diagnostic Log to Desktop**.

Send the generated `Finder-Actions-Diagnostics-<timestamp>.log` file to the developer. The log may contain local file paths and script output, so review it in a text editor before sharing. Disable diagnostics after troubleshooting.

## License

[MIT](LICENSE)
