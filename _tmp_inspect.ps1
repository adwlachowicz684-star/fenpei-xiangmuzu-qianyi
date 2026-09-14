$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$target = Get-ChildItem -Path $root -Recurse -Filter 'index.html' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like '*\dist\index.html' -and $_.FullName -notlike '*\node_modules\*' } |
    Select-Object -First 1
if (-not $target) { Write-Output 'NOT FOUND'; exit 1 }
Write-Output ('TARGET=' + $target.FullName)
$lines = [System.IO.File]::ReadAllLines($target.FullName, [System.Text.Encoding]::UTF8)
for ($i = 952; $i -le 968 -and $i -lt $lines.Length; $i++) {
    $t = $lines[$i].Replace("`t", '<TAB>')
    Write-Output ('{0}: {1}' -f ($i + 1), $t)
}
