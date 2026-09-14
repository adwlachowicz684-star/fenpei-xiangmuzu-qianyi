$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = 'E:\_project\AIProject_项目\工具开发\分配项目组迁移\资源\kityminder.ui.zip'
$installed = 'E:\_project\AIProject_项目\工具开发\分配项目组迁移\数据\plugins\kityminder\dist\index.html'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = 'E:\_project\AIProject_项目\工具开发\分配项目组迁移\资源\kityminder.ui.zip.bak-' + $stamp
Copy-Item -LiteralPath $zipPath -Destination $backup
Write-Output ('backup=' + $backup)
$newBytes = [System.IO.File]::ReadAllBytes($installed)
$z = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Update)
$e = $z.Entries | Where-Object { $_.FullName -eq 'dist/index.html' } | Select-Object -First 1
if (-not $e) { $z.Dispose(); throw 'dist/index.html not found in zip' }
$s = $e.Open()
$s.SetLength(0)
$s.Write($newBytes, 0, $newBytes.Length)
$s.Close()
$z.Dispose()
Write-Output 'zip updated'
