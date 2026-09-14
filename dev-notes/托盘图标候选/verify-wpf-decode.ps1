# WPF-decode the embedded tray.ico exactly like the button loader. (ASCII only)
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

$dist = Join-Path $PSScriptRoot '..\..\dist'
$dll = Get-ChildItem $dist -Filter *.dll | Select-Object -First 1
$asm = [System.Reflection.Assembly]::LoadFrom($dll.FullName)
$name = $asm.GetManifestResourceNames() | Where-Object { $_ -like '*tray.ico' } | Select-Object -First 1
if (-not $name) { Write-Host 'no tray.ico resource'; exit 1 }

$stream = $asm.GetManifestResourceStream($name)
$ms = New-Object System.IO.MemoryStream
$stream.CopyTo($ms); $stream.Dispose()
$bytes = $ms.ToArray(); $ms.Dispose()

$mem = New-Object System.IO.MemoryStream(,$bytes)
$decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create($mem, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
Write-Host ("frames=" + $decoder.Frames.Count)
foreach ($f in $decoder.Frames) { Write-Host ("  " + $f.PixelWidth + "x" + $f.PixelHeight) }
$mem.Dispose()