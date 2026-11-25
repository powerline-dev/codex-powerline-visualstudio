# Codex Powerline for Visual Studio

This repository hosts the Windows x64 Visual Studio extension, not the VS Code
extension. Keep CLI widgets, themes, settings, and Codex integration in the CLI.
Run the installed `codex-powerline run` command in a real PTY.

## Architecture

- `src/PowerlinePackage.cs`, `src/Commands.vsct`: VSSDK package and menu command.
- `src/TerminalControl.cs`: WPF/WebView2 tool window and origin-checked messaging.
- `src/TerminalProcess.cs`: .NET Framework UTF-8 transport to the Node.js helper.
- `src/terminal-host.cjs`: node-pty session, backpressure, restart, and shutdown.
- `web/`: xterm.js frontend and Powerline font.
- `scripts/build.ps1`: supported build and release workflow.

## Checks

On Windows x64, run `npm ci` and `./scripts/build.ps1`. The script checks
TypeScript, builds the frontend/helper, runs native integration tests, builds
the VSIX with Visual Studio MSBuild, and checks the .NET transport.
Use `./scripts/build.ps1 -Release` to copy the VSIX and checksum to the versioned
release folder. Never publish or install into the user's normal IDE profile
without authorization.

For UI changes, check an experimental instance of Visual Studio 2022 and 2026.
Check keyboard input, paste, resize, hide/show, restart, and IDE shutdown.
Report UI checks that were not run. Preserve supplied branding and `.github`
metadata. Keep the npm, project, and VSIX manifest versions in sync.
