param(
    [string]$CommandTablePath = (Join-Path $PSScriptRoot '../src/Commands.vsct'),
    [string]$AssemblyPath
)
$ErrorActionPreference = 'Stop'
[xml]$table = Get-Content -LiteralPath $CommandTablePath -Raw
$namespace = [Xml.XmlNamespaceManager]::new($table.NameTable)
$namespace.AddNamespace('v', 'http://schemas.microsoft.com/VisualStudio/2005-10-18/CommandTable')
$kinds = @{}
foreach ($kind in @('Group', 'Menu')) {
    foreach ($item in $table.SelectNodes("//v:$kind", $namespace)) {
        $kinds["$($item.guid):$($item.id)"] = $kind
    }
}
foreach ($group in $table.SelectNodes('//v:Group', $namespace)) {
    $parent = $group.SelectSingleNode('v:Parent', $namespace)
    if (!$parent) { continue }
    if ($parent.id -like 'IDG_*' -or $kinds["$($parent.guid):$($parent.id)"] -eq 'Group') {
        throw "Group '$($group.id)' has another group as its parent. Groups must belong to a menu or toolbar."
    }
}
foreach ($button in $table.SelectNodes('//v:Button', $namespace)) {
    $parent = $button.SelectSingleNode('v:Parent', $namespace)
    if (!$parent) { throw "Command '$($button.id)' has no parent group." }
    if ($parent.id -like 'IDM_*' -or $kinds["$($parent.guid):$($parent.id)"] -eq 'Menu') {
        throw "Command '$($button.id)' has a menu as its parent. Commands must belong to a group."
    }
}
if ($AssemblyPath) {
    $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $AssemblyPath)))
    $found = $false
    foreach ($name in $assembly.GetManifestResourceNames()) {
        $reader = [Resources.ResourceReader]::new($assembly.GetManifestResourceStream($name))
        try {
            foreach ($entry in $reader) {
                if ($entry.Key -eq 'Menus.ctmenu' -and $entry.Value.Length -gt 0) { $found = $true }
            }
        }
        finally { $reader.Dispose() }
    }
    if (!$found) { throw 'The built assembly does not contain the registered Menus.ctmenu command resource.' }
}
Write-Output 'PASS command-table hierarchy and compiled menu resource (when supplied).'
