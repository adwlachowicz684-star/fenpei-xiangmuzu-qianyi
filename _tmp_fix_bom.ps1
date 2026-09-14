$ErrorActionPreference = 'Stop'
$p = Join-Path $PSScriptRoot '_tmp_check_zip.ps1'
$c = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))
Write-Output 'BOM added'
