# Codex Powerline for Visual Studio 0.1.1

[Download the Visual Studio VSIX](codex-powerline-visualstudio-0.1.1.vsix).
On GitHub, open the file and select **Download raw file**.

## Fix

Version 0.1.0 placed the tool-window command inside a group nested under another
group. Visual Studio cannot display that hierarchy. Version 0.1.1 places the
command directly in the built-in **View > Other Windows** group.

The release build also regenerates the VSIX manifest and checks the version
inside the archive, so stale generated metadata cannot hide an upgrade.

The extension identity is unchanged, so this package upgrades 0.1.0.

The menu entry and command-driven tool-window startup were checked in isolated
Visual Studio 2022 and 2026 profiles with a mock CLI. The build, native terminal
tests, .NET transport check, and menu hierarchy regression check also passed.

## Install or update

1. Close every Visual Studio instance.
2. Open `codex-powerline-visualstudio-0.1.1.vsix` and select your Visual Studio installation.
3. Reopen Visual Studio and select **View > Other Windows > Codex Powerline**.

Supports x64 Visual Studio 2022 17.14+ and Visual Studio 2026. Requires x64
Node.js 22.12+, Codex CLI, Powerline CLI, and the WebView2 Runtime.
See the [main README](../../README.md#-install) for setup.

Check the package against [SHA256SUMS.txt](SHA256SUMS.txt):

```powershell
Get-FileHash ./codex-powerline-visualstudio-0.1.1.vsix -Algorithm SHA256
```
