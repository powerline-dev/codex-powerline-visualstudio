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

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$publisher = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VSSDK -find 'VSSDK/VisualStudioIntegration/Tools/Bin/VsixPublisher.exe' | Select-Object -First 1
if (!$publisher) { throw 'VsixPublisher.exe was not found on the runner.' }
$package = Get-Item -LiteralPath "artifacts/codex-powerline-visualstudio-$Version.vsix"

if (!$env:ACTIONS_ID_TOKEN_REQUEST_URL -or !$env:ACTIONS_ID_TOKEN_REQUEST_TOKEN) {
    throw 'GitHub Actions did not supply an OIDC token request URL and credential.'
}
$separator = if ($env:ACTIONS_ID_TOKEN_REQUEST_URL.Contains('?')) { '&' } else { '?' }
$oidcUrl = "$($env:ACTIONS_ID_TOKEN_REQUEST_URL)${separator}audience=marketplace.visualstudio.com"
$oidc = Invoke-RestMethod -Method Get -TimeoutSec 30 -Uri $oidcUrl `
    -Headers @{ Authorization = "Bearer $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN"; Accept = 'application/json' }
if (!$oidc.value) { throw 'GitHub Actions did not return an OIDC token.' }
Write-Output "::add-mask::$($oidc.value)"

# The runner's -oidc exchange omits the API version. See microsoft/vsmarketplace#2310.
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
