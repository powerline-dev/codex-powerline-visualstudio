param(
    [Parameter(Mandatory)][string]$VisualStudioPath,
    [Parameter(Mandatory)][string]$InstanceId,
    [string]$RootSuffix = 'PowerlineMenuTest'
)
$ErrorActionPreference = 'Stop'
if ($RootSuffix -notmatch '^Powerline[A-Za-z0-9]+$') { throw 'Use a dedicated Powerline experimental suffix, never the normal IDE profile.' }
$repo = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('powerline-vs-menu-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$ide = $null
$dte = $null
try {
    Push-Location $repo
    try {
        & (Join-Path $VisualStudioPath 'MSBuild/Current/Bin/MSBuild.exe') CodexPowerline.VisualStudio.csproj /t:Rebuild /p:Configuration=Release /p:DeployExtension=true "/p:DeployTargetInstanceId=$InstanceId" "/p:VSSDKTargetPlatformRegRootSuffix=$RootSuffix" /v:minimal /nologo
        if ($LASTEXITCODE -ne 0) { throw 'Experimental VSIX deployment failed.' }
    }
    finally { Pop-Location }

    if (!('PowerlineMenuRot' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class PowerlineMenuRot {
    [DllImport("ole32.dll")] private static extern int GetRunningObjectTable(int reserved, out IRunningObjectTable table);
    [DllImport("ole32.dll")] private static extern int CreateBindCtx(int reserved, out IBindCtx context);
    public static object Find(int processId) {
        IRunningObjectTable table; IBindCtx context; IEnumMoniker entries;
        GetRunningObjectTable(0, out table); CreateBindCtx(0, out context);
        table.EnumRunning(out entries);
        var monikers = new IMoniker[1];
        try {
            while (entries.Next(1, monikers, IntPtr.Zero) == 0) {
                try {
                    string name; monikers[0].GetDisplayName(context, null, out name);
                    if (name.Contains("VisualStudio.DTE.") && name.EndsWith(":" + processId)) {
                        object instance; table.GetObject(monikers[0], out instance); return instance;
                    }
                } finally { Marshal.ReleaseComObject(monikers[0]); }
            }
            return null;
        } finally {
            Marshal.ReleaseComObject(entries); Marshal.ReleaseComObject(context); Marshal.ReleaseComObject(table);
        }
    }
}
'@
    }
    $node = (Get-Command node -CommandType Application).Source
    [IO.File]::WriteAllText((Join-Path $fixture 'codex-powerline.cmd'), "@`"$node`" `"%~dp0mock.cjs`"`r`n")
    [IO.File]::WriteAllText((Join-Path $fixture 'mock.cjs'), "require('node:fs').writeFileSync(process.env.POWERLINE_MENU_SMOKE_MARKER, String(process.pid)); console.log('MENU_SMOKE_READY'); setInterval(() => {}, 1000);")
    $marker = Join-Path $fixture 'cli-started.txt'
    $activityLog = Join-Path $fixture 'ActivityLog.xml'
    $solution = Join-Path $fixture 'Smoke.sln'
    [IO.File]::WriteAllText($solution, "Microsoft Visual Studio Solution File, Format Version 12.00`r`n# Visual Studio Version 17`r`nVisualStudioVersion = 17.14.37906.3`r`nMinimumVisualStudioVersion = 10.0.40219.1`r`nGlobal`r`nEndGlobal`r`n")
    $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $VisualStudioPath 'Common7/IDE/devenv.exe'))
    $start.Arguments = "`"$solution`" /RootSuffix $RootSuffix /NoSplash /Log `"$activityLog`""
    $start.UseShellExecute = $false
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.EnvironmentVariables['PATH'] = "$fixture;$env:PATH"
    $start.EnvironmentVariables['POWERLINE_MENU_SMOKE_MARKER'] = $marker
    $ide = [Diagnostics.Process]::Start($start)

    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    $command = $null
    while ([DateTime]::UtcNow -lt $deadline -and !$ide.HasExited) {
        try {
            $dte = [PowerlineMenuRot]::Find($ide.Id)
            if ($dte) {
                $command = $dte.Commands.Item('{40fbb5cd-94aa-4539-bf64-9f42f385996a}', 0x0100)
                if ($command -and $command.IsAvailable) { break }
            }
        }
        catch { }
        Start-Sleep -Milliseconds 500
    }
    if (!$command -or !$command.IsAvailable) { throw "The command is not registered or available. Activity log: $activityLog" }
    Write-Output "Registered command: $($command.Name)"
    $menu = $dte.CommandBars.Item('Other Windows')
    $entry = @($menu.Controls | Where-Object { ($_.Caption -replace '&', '') -eq 'Codex Powerline' })
    if (!$entry.Count) { throw 'Codex Powerline is not present in the Other Windows menu.' }
    Write-Output 'PASS actual Visual Studio Other Windows menu contains Codex Powerline.'
    $dte.ExecuteCommand($command.Name)
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (!(Test-Path -LiteralPath $marker) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 500 }
    if (!(Test-Path -LiteralPath $marker)) { throw "The tool window did not start the mock CLI. Activity log: $activityLog" }
    Write-Output 'PASS menu command opens the tool window and starts the mock CLI.'
}
finally {
    if ($dte) { try { $dte.Quit() } catch { } }
    if ($ide -and !$ide.HasExited -and !$ide.WaitForExit(10000)) { $ide.Kill() }
    Write-Output "Experimental test artifacts: $fixture"
}
