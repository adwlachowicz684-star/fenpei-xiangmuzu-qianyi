$ErrorActionPreference = 'Stop'
Get-ChildItem -Path $PSScriptRoot -Filter '_tmp_*.ps1' -File | ForEach-Object {
    $p = $_.FullName
    $c = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))
}
Write-Output 'All tmp scripts BOM-fixed'
