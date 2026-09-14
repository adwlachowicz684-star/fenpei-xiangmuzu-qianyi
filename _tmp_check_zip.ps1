$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = 'E:\_project\AIProject_项目\工具开发\分配项目组迁移\资源\kityminder.ui.zip'
$installed = 'E:\_project\AIProject_项目\工具开发\分配项目组迁移\数据\plugins\kityminder\dist\index.html'
$z = [System.IO.Compression.ZipFile]::OpenRead($zip)
Write-Output '=== entries containing index.html ==='
$z.Entries | Where-Object { $_.FullName -like '*index.html*' } | ForEach-Object { Write-Output ($_.FullName + '  len=' + $_.Length) }
$e = $z.Entries | Where-Object { $_.FullName -eq 'dist/index.html' } | Select-Object -First 1
if ($e) {
    $ms = New-Object System.IO.MemoryStream
    $s = $e.Open()
    $s.CopyTo($ms)
    $s.Close()
    $zipBytes = $ms.ToArray()
    $installedBytes = [System.IO.File]::ReadAllBytes($installed)
    Write-Output ('zipLen=' + $zipBytes.Length + ' installedLen=' + $installedBytes.Length)
    $same = $true
    if ($zipBytes.Length -ne $installedBytes.Length) {
        $same = $false
        Write-Output ('length differ')
    } else {
        for ($i = 0; $i -lt $zipBytes.Length; $i++) {
            if ($zipBytes[$i] -ne $installedBytes[$i]) {
                $same = $false
                Write-Output ('firstDiff@' + $i)
                break
            }
        }
    }
    Write-Output ('identical=' + $same)
} else {
    Write-Output 'no dist/index.html in zip'
}
$z.Dispose()
