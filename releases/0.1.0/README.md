# Codex Powerline for Visual Studio 0.1.0

This version has a menu placement bug. Use [0.1.1](../0.1.1/) instead.

[Download the Visual Studio VSIX](codex-powerline-visualstudio-0.1.0.vsix).
On GitHub, open the file and select **Download raw file**.

This package is for Windows x64 Visual Studio 2022 17.14+ and Visual Studio 2026
(Community, Professional, and Enterprise). It does not install in VS Code or
native ARM64 Visual Studio.

## Install

1. Install x64 Node.js 22.12+, Codex CLI, and Codex Powerline CLI.
2. Install Microsoft Edge WebView2 Evergreen Runtime if needed.
3. Close Visual Studio and open the downloaded VSIX to install it.
4. Open **View > Other Windows > Codex Powerline**.

See the [main README](../../README.md#-install) for setup commands.

## Included

- Dockable WPF/WebView2 terminal with xterm.js and bundled Powerline glyphs.
- Native Windows ConPTY host that runs the installed `codex-powerline run`.
- Active project/solution directory selection, resize, input, and output flow control.
- Restart action, theme colors, persistent hidden sessions, and shutdown cleanup.

## Checks

The release workflow runs TypeScript checks, native terminal integration tests,
the Visual Studio SDK build, and a .NET Framework UTF-8 transport smoke check.
These do not replace manual checks of docking, keyboard routing, clipboard,
theme changes, and IDE shutdown inside each supported Visual Studio version.

Check the download against [SHA256SUMS.txt](SHA256SUMS.txt):

```powershell
Get-FileHash ./codex-powerline-visualstudio-0.1.0.vsix -Algorithm SHA256
```

This is a prepared repository release, not a Marketplace publication.
