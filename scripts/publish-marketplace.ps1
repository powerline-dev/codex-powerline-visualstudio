param(
    [Parameter(Mandatory)]
    [version]$Version
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content vsix-publish.json -Raw | ConvertFrom-Json
$extensionId = "$($manifest.publisher).$($manifest.identity.internalName)"

# Use the Marketplace extension query to check the existing VSIX versions.
$query = @{
    filters = @(@{
        criteria = @(@{ filterType = 7; value = $extensionId }) # Full extension ID
        pageNumber = 1
        pageSize = 1
    })
    assetTypes = @()
    flags = 1 # Include versions
} | ConvertTo-Json -Depth 5
$gallery = Invoke-RestMethod -Method Post -TimeoutSec 30 `
    -Uri 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery' `
    -Headers @{ Accept = 'application/json;api-version=3.0-preview.1' } `
    -ContentType 'application/json' -Body $query
if ($gallery.results.Count -ne 1 -or $null -eq $gallery.results[0].extensions) {
    throw 'Marketplace returned an invalid extension query result.'
}
foreach ($extension in $gallery.results[0].extensions) {
    if ("$($extension.publisher.publisherName).$($extension.extensionName)" -ne $extensionId -or !$extension.versions) {
        throw 'Marketplace returned unexpected extension metadata.'
    }
    foreach ($release in $extension.versions) {
        if ([version]$release.version -ge $Version) {
            Write-Output "Skipping $Version because $($release.version) is already on Marketplace."
            return
        }
    }
}

$package = Get-Item -LiteralPath "artifacts/codex-powerline-visualstudio-$Version.vsix"

if (!$env:ACTIONS_ID_TOKEN_REQUEST_URL -or !$env:ACTIONS_ID_TOKEN_REQUEST_TOKEN) {
    throw 'GitHub Actions did not supply an OIDC token request URL and credential.'
}

# Use an isolated publisher instead of the runner's Visual Studio installation.
$buildToolsVersion = '18.12.1606'
$publisherDirectory = Join-Path $env:RUNNER_TEMP "vssdk-publisher-$buildToolsVersion"
$archivePath = "$publisherDirectory.zip"
Invoke-WebRequest -TimeoutSec 120 -OutFile $archivePath -Uri (
    "https://api.nuget.org/v3-flatcontainer/microsoft.vssdk.buildtools/$buildToolsVersion/microsoft.vssdk.buildtools.$buildToolsVersion.nupkg"
)
Expand-Archive -LiteralPath $archivePath -DestinationPath $publisherDirectory
$publisher = Join-Path $publisherDirectory 'tools/VSSDK/bin/VsixPublisher.exe'

# This BuildTools package ships MSAL 4.87, but the publisher references 4.85.2.
$msalPath = Join-Path (Split-Path $publisher) 'lib/Microsoft.Identity.Client.dll'
$msalVersion = [Reflection.AssemblyName]::GetAssemblyName($msalPath).Version
$configPath = "$publisher.config"
[xml]$config = Get-Content -LiteralPath $configPath -Raw
$namespace = 'urn:schemas-microsoft-com:asm.v1'
$binding = $config.SelectSingleNode("/configuration/runtime/*[local-name()='assemblyBinding' and namespace-uri()='$namespace']")
$redirect = $config.CreateDocumentFragment()
$redirect.InnerXml = @"
<dependentAssembly xmlns="$namespace">
    <assemblyIdentity name="Microsoft.Identity.Client" publicKeyToken="0a613f4dd989e8ae" culture="neutral" />
    <bindingRedirect oldVersion="4.85.2.0" newVersion="$msalVersion" />
</dependentAssembly>
"@
[void]$binding.AppendChild($redirect)
$config.Save($configPath)

$separator = if ($env:ACTIONS_ID_TOKEN_REQUEST_URL.Contains('?')) { '&' } else { '?' }
$oidcUrl = "$($env:ACTIONS_ID_TOKEN_REQUEST_URL)${separator}audience=marketplace.visualstudio.com"
$oidc = Invoke-RestMethod -Method Get -TimeoutSec 30 -Uri $oidcUrl `
    -Headers @{ Authorization = "Bearer $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN"; Accept = 'application/json' }
if (!$oidc.value) { throw 'GitHub Actions did not return an OIDC token.' }
Write-Output "::add-mask::$($oidc.value)"

# Exchange the token explicitly to include the API version. See microsoft/vsmarketplace#2310.
$exchange = Invoke-RestMethod -Method Post -TimeoutSec 30 `
    -Uri 'https://marketplace.visualstudio.com/_apis/gallery/token?api-version=7.2-preview.1' `
    -Headers @{
        Authorization = "FederatedToken $($oidc.value)"
        Accept = 'application/json'
        'X-Market-CI-Provider' = 'github-actions'
    } `
    -ContentType 'application/json' `
    -Body (@{ publisherName = $manifest.publisher } | ConvertTo-Json -Compress)
if (!$exchange.credential) { throw 'Marketplace did not return a publishing credential.' }
Write-Output "::add-mask::$($exchange.credential)"

& $publisher publish -payload $package.FullName -publishManifest (Resolve-Path vsix-publish.json).Path -personalAccessToken $exchange.credential
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
