<div align="center">

# ![Codex Powerline for Visual Studio](assets/header.png)

**Your Codex terminal. Your Powerline layout. Inside Visual Studio.**

Run the [Codex Powerline CLI](https://github.com/powerline-dev/codex-powerline-cli)
beside your code in a dockable tool window. Keep your model, context, usage
limits, and Git state close, with your CLI themes, widgets, and saved layouts.

Give a ⭐ if this project helped you!

[![GitHub stars](https://img.shields.io/github/stars/powerline-dev/codex-powerline-visualstudio?style=social)](https://github.com/powerline-dev/codex-powerline-visualstudio)
[![GitHub forks](https://img.shields.io/github/forks/powerline-dev/codex-powerline-visualstudio?style=social)](https://github.com/powerline-dev/codex-powerline-visualstudio/forks)
[![GitHub watchers](https://img.shields.io/github/watchers/powerline-dev/codex-powerline-visualstudio?style=social)](https://github.com/powerline-dev/codex-powerline-visualstudio)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Visual Studio: 2022 / 2026](https://img.shields.io/badge/Visual_Studio-2022_%2F_2026-5C2D91)](https://visualstudio.microsoft.com/)
[![Node.js: 22.12+](https://img.shields.io/badge/Node.js-22.12%2B-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)

[![GitHub issues](https://img.shields.io/github/issues/powerline-dev/codex-powerline-visualstudio)](https://github.com/powerline-dev/codex-powerline-visualstudio/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/powerline-dev/codex-powerline-visualstudio)](https://github.com/powerline-dev/codex-powerline-visualstudio/pulls)
[![GitHub contributors](https://img.shields.io/github/contributors/powerline-dev/codex-powerline-visualstudio)](https://github.com/powerline-dev/codex-powerline-visualstudio/graphs/contributors)

[📦 Download the VSIX](releases/0.1.1/) · [⚡ Powerline CLI](https://github.com/powerline-dev/codex-powerline-cli) · [🐛 Report a bug](https://github.com/powerline-dev/codex-powerline-visualstudio/issues)

</div>

## Contents

- [Install](#-install)
- [Features](#-features)
- [Configure](#configure)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Release preparation](#release-preparation)
- [Contributing](#-contributing)
- [Author and acknowledgments](#author-and-acknowledgments)
- [License](#license)

## 🚀 Install

This is a **Visual Studio** extension, not a VS Code extension. The initial
release targets **Windows x64**, **Visual Studio 2022 17.14 or newer**, and
**Visual Studio 2026**, in Community, Professional, and Enterprise editions.
Native ARM64 Visual Studio is not included in this release.

### 1. Set up the CLI

Install [x64 Node.js 22.12 or newer](https://nodejs.org/). In PowerShell, run:

```powershell
npm install --global @openai/codex @powerline-dev/codex-powerline-cli
codex login
codex-powerline configure
```

The Powerline npm command applies once the scoped package is published. Until
then, use the [CLI development setup](https://github.com/powerline-dev/codex-powerline-cli#development).
Make sure `node`, `codex`, and `codex-powerline` are on PATH. Restart Visual Studio
after you install or update Node.js or change PATH.

### 2. Install the extension

Download [Codex Powerline 0.1.1 for Visual Studio](https://github.com/powerline-dev/codex-powerline-visualstudio/raw/refs/heads/main/releases/0.1.1/codex-powerline-visualstudio-0.1.1.vsix).
The link becomes available after the release folder is pushed to GitHub.

Close Visual Studio, open the `.vsix` file, and choose the Visual Studio instance
where you want to install it. The extension is not yet published to Marketplace.

If you installed 0.1.0, install 0.1.1 over it. Version 0.1.0 has a menu placement
bug that hides the command under **View > Other Windows**.

The terminal also needs the [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).
If the tool window reports that the runtime is missing, install the Evergreen
Runtime and restart Visual Studio.

### 3. Open your terminal

Open **View > Other Windows > Codex Powerline**. Dock the tool window beside
your editor, float it on another monitor, or pin it beside Solution Explorer.
Widen it to give your Powerline layout more columns.

You can also run `View.CodexPowerline` in Visual Studio's Command Window.

The terminal starts in the active document's project folder, then falls back
to the solution folder, active local file's folder, or your home folder.
Changing projects does not move a running session. Use **Restart Terminal**
to start in the newly active project.

## ✨ Features

- 💻 **Keep Codex close.** Use an interactive terminal in a real Visual Studio tool window.
- 🎨 **Make it yours.** Reuse the CLI's themes, presets, widgets, and saved layouts.
- ⏱️ **Know what's left.** Keep the CLI's context and usage-limit widgets beside your code.
- 🌿 **Stay oriented.** Start in your active project and use the CLI's Git widgets.
- 🔤 **Keep the Powerline look.** Bundled font symbols cover the Powerline separators.
- 🧠 **Keep your session.** Hide or auto-hide the tool window without restarting the CLI.
- 🔄 **Start fresh.** Use **Restart Terminal** to start a new CLI process in the active project.
- 🌓 **Match your editor.** The terminal background and foreground follow Visual Studio's theme.

The extension hosts `codex-powerline run`. The CLI owns the settings, widgets,
themes, presets, and Codex integration. No separate Core package is needed.

## Configure

Choose your widgets, tweak your rows, and try a theme in the CLI's live editor:

```powershell
codex-powerline configure
```

Save your layout, then select **Restart Terminal** in the tool window.
The initial extension uses Consolas at 14 pixels, with bundled Powerline glyphs.
Visual Studio's editor font settings do not change this terminal's font.

Update the CLI separately from the extension:

```powershell
npm install --global @powerline-dev/codex-powerline-cli@latest
```

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Node.js was not found | Install x64 Node.js 22.12 or newer and fully restart Visual Studio. |
| The CLI exits immediately | Run `codex-powerline run` in PowerShell. Check Codex login and both CLI installs. |
| The browser cannot start | Install or repair the Microsoft Edge WebView2 Evergreen Runtime. |
| A layout is too wide | Widen the tool window or choose a compact CLI layout. |
| Changes do not appear | Save the layout, then select **Restart Terminal**. |
| The VSIX does not install | Use x64 Visual Studio 2022 17.14+ or Visual Studio 2026, not VS Code or ARM64 Visual Studio. |
| Codex Powerline is missing from Other Windows | Upgrade from 0.1.0 to 0.1.1, then fully restart Visual Studio. Check that the extension is enabled in **Extensions > Manage Extensions**. |

## Development

You need Windows x64, Node.js 22.12+, and Visual Studio 2022 17.14+ or 2026 with
the **.NET desktop development** workload. NuGet restores the SDK build tools
and .NET Framework reference assemblies. No sibling checkout is needed.

```powershell
git clone https://github.com/powerline-dev/codex-powerline-visualstudio.git
cd codex-powerline-visualstudio
npm ci
npm run check
npm run build
npm test
./scripts/build.ps1
```

Open `CodexPowerline.VisualStudio.csproj` in Visual Studio for C# changes.
The build script finds MSBuild with `vswhere` and builds a Release VSIX.

The build also checks command-table parent types and the embedded menu resource.
To check the real menu and tool-window startup in an isolated IDE profile, run:

```powershell
./tests/Test-VisualStudioMenu.ps1 -VisualStudioPath '<Visual Studio installation path>' -InstanceId '<vswhere instance ID>'
```

This uses the `PowerlineMenuTest` experimental profile and a mock CLI. It does
not change your normal Visual Studio profile or start your real Codex session.

| Path | Purpose |
| --- | --- |
| `src/PowerlinePackage.cs` and `src/Commands.vsct` | Package registration and the View menu command. |
| `src/TerminalControl.cs` | Dockable WebView2 terminal, themes, and restart action. |
| `src/WorkspaceDirectory.cs` | Project and solution directory selection. |
| `src/TerminalProcess.cs` | UTF-8 process transport and host cleanup. |
| `src/terminal-host.cjs` | Native PTY, resize, bounded output flow, and CLI lifecycle. |
| `web/` | xterm.js terminal, keyboard input, and bundled symbols. |
| `tests/` | Native terminal integration checks with a mock CLI. |
| `releases/<version>/` | Installable VSIX, notes, and SHA-256 checksum. |

The WPF tool window uses the Visual Studio SDK. WebView2 loads only packaged
assets from a restricted local origin. The Node.js helper uses `node-pty` and
Windows ConPTY, so the CLI receives a real interactive terminal.

## Release preparation

Update the version in the project, VSIX manifest, and npm metadata, then run:

```powershell
./scripts/build.ps1 -Release
```

This checks the frontend, builds the assets, runs native integration tests,
builds the VSIX, and copies it with a SHA-256 checksum to `releases/<version>/`.
It does not install into your normal Visual Studio profile or publish anything.

Before publication, install into an experimental Visual Studio instance and
check the menu, docking, keyboard input, clipboard, resizing, hide/show, restart,
solution selection, theme changes, and IDE shutdown on each supported version.

## 🤝 Contributing

Contributions are welcome! Open an issue to report a bug or discuss a larger
change. Create a focused branch, run `./scripts/build.ps1`, and check the tool
window in an isolated Visual Studio instance before you open a pull request.

## Author and acknowledgments

**Martin Hájek** is the author and maintainer of Codex Powerline.

The [Powerline CLI](https://github.com/powerline-dev/codex-powerline-cli) is based
on [ccstatusline](https://github.com/sirmalloc/ccstatusline) by Matthew Breedlove.
This extension uses [xterm.js](https://github.com/xtermjs/xterm.js),
[node-pty](https://github.com/microsoft/node-pty), and Microsoft WebView2.
See [NOTICE](NOTICE) for attribution.

## License

MIT. See [LICENSE](LICENSE) for the terms and copyright notices.
