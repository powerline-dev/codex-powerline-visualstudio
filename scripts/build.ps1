param([switch]$Release)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    foreach ($script in @('check', 'build', 'test')) {
        & npm run $script
        if ($LASTEXITCODE -ne 0) { throw "npm run $script failed." }
    }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio Installer (vswhere) was not found.' }
    $msbuild = & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild/Current/Bin/MSBuild.exe' | Select-Object -First 1
    if (!$msbuild) { throw 'Visual Studio MSBuild was not found. Install the .NET desktop development workload.' }
    & $msbuild CodexPowerline.VisualStudio.csproj /restore /p:Configuration=Release /v:minimal /nologo
    if ($LASTEXITCODE -ne 0) { throw 'The VSIX build failed.' }
    & dotnet run --project tests/TransportSmoke/TransportSmoke.csproj --configuration Release -- (Join-Path (Get-Location) 'bin/Release/net472')
    if ($LASTEXITCODE -ne 0) { throw 'The .NET terminal transport check failed.' }
    if ($Release) {
        $version = (Get-Content package.json -Raw | ConvertFrom-Json).version
        $folder = Join-Path 'releases' $version
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $filename = "codex-powerline-visualstudio-$version.vsix"
        $package = Get-ChildItem bin/Release -Filter '*.vsix' -Recurse | Select-Object -First 1
        if (!$package) { throw 'The build did not produce a VSIX.' }
        $destination = Join-Path $folder $filename
        Copy-Item -LiteralPath $package.FullName -Destination $destination
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText((Join-Path (Get-Location) "$folder/SHA256SUMS.txt"), "$hash  $filename`n", [Text.UTF8Encoding]::new($false))
        Write-Output "Release package: $destination"
    }
}
finally { Pop-Location }
