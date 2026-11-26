# Development

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

## Publish to Visual Studio Marketplace

In GitHub, create an environment named `marketplace-release` and restrict its
deployment branches to `main`. In the [Powerline Dev publisher](https://marketplace.visualstudio.com/manage/publishers/powerline-dev),
open **Trusted Publishing** and create a policy with these values.

| Field | Value |
| --- | --- |
| Repository owner | `powerline-dev` |
| Repository | `codex-powerline-visualstudio` |
| Workflow | `publish-marketplace.yml` |
| Environment | `marketplace-release` |

In GitHub Actions, run **Publish Visual Studio extension** on `main`.
Leave `publish` unchecked to build and download the Windows x64 package from the
run. Check `publish` to send the build to the Marketplace using Trusted Publishing.
Bump the version in the project, VSIX manifest, and npm metadata before publishing
an update.

See [Microsoft's Trusted Publishing setup](https://developer.microsoft.com/blog/trusted-publishing-visual-studio-marketplace/).

## Contribution checks

Contributions are welcome! Open an issue to report a bug or discuss a larger
change. Create a focused branch, run `./scripts/build.ps1`, and check the tool
window in an isolated Visual Studio instance before you open a pull request.

[Back to the project README](../README.md)
