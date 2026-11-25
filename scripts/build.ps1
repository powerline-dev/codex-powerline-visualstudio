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
    & $msbuild CodexPowerline.VisualStudio.csproj /restore /t:Rebuild /p:Configuration=Release /v:minimal /nologo
    if ($LASTEXITCODE -ne 0) { throw 'The VSIX build failed.' }
    & ./tests/Test-CommandTable.ps1 -AssemblyPath bin/Release/net472/CodexPowerline.VisualStudio.dll
    & dotnet run --project tests/TransportSmoke/TransportSmoke.csproj --configuration Release -- (Join-Path (Get-Location) 'bin/Release/net472')
    if ($LASTEXITCODE -ne 0) { throw 'The .NET terminal transport check failed.' }
    $version = (Get-Content package.json -Raw | ConvertFrom-Json).version
    $package = Get-ChildItem bin/Release -Filter '*.vsix' -Recurse | Select-Object -First 1
    if (!$package) { throw 'The build did not produce a VSIX.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($package.FullName)
    try {
        $reader = [IO.StreamReader]::new($archive.GetEntry('extension.vsixmanifest').Open())
        try { [xml]$packedManifest = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
        [xml]$sourceManifest = Get-Content source.extension.vsixmanifest -Raw
        $packedIdentity = $packedManifest.PackageManifest.Metadata.Identity
        $sourceIdentity = $sourceManifest.PackageManifest.Metadata.Identity
        if ($packedIdentity.Version -ne $version -or $packedIdentity.Version -ne $sourceIdentity.Version -or $packedIdentity.Id -ne $sourceIdentity.Id) {
            throw 'The VSIX has stale or mismatched version/identity metadata.'
        }
    }
    finally { $archive.Dispose() }
    Write-Output "PASS packaged VSIX version and identity: $version"
    if ($Release) {
        $folder = Join-Path 'releases' $version
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $filename = "codex-powerline-visualstudio-$version.vsix"
        $destination = Join-Path $folder $filename
        Copy-Item -LiteralPath $package.FullName -Destination $destination
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText((Join-Path (Get-Location) "$folder/SHA256SUMS.txt"), "$hash  $filename`n", [Text.UTF8Encoding]::new($false))
        Write-Output "Release package: $destination"
    }
}
finally { Pop-Location }
