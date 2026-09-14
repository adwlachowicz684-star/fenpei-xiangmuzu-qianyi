# Crop MCP panel region from window and save zoomed view (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32b {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$projRoot = Split-Path -Parent $PSScriptRoot

$proc = Get-Process -Name "分配项目组" | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle
$wr = New-Object W32b+RECT
[W32b]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left
$h = $wr.Bottom - $wr.Top
Write-Host "window $w x $h at $($wr.Left),$($wr.Top)"

# MCP panel: top-right, 800 wide. Crop x from right-800 to right, y from 40 to 640
$cropW = [Math]::Min(800, $w)
$cropH = [Math]::Min(640, $h - 40)
$sx = $wr.Right - $cropW
$sy = $wr.Top + 40

$bmp = New-Object System.Drawing.Bitmap($cropW, $cropH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($sx, $sy, 0, 0, $bmp.Size)
$out = Join-Path $projRoot '界面截图_MCP面板2列_裁剪.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved $out"
