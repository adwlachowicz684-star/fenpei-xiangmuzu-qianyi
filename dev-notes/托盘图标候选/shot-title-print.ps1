# Capture the app window via PrintWindow, crop the title-bar tray button. (ASCII only)
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PW {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public const uint PW_RENDERFULLCONTENT = 0x2;
}
"@

$proc = Get-Process | Where-Object { $_.Path -and $_.Path -like '*dist*' -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle
$rect = New-Object PW+RECT
[PW]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Host ("win rect " + $w + "x" + $h)

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dc = $g.GetHdc()
[PW]::PrintWindow($hwnd, $dc, [PW]::PW_RENDERFULLCONTENT) | Out-Null
$g.ReleaseHdc($dc)
$g.Dispose()

# crop title bar right region (window coords, no DPI issue)
$cw = 420; $ch = 80
$cx = $w - $cw; $cy = 0
$zoom = 5
$outW = $cw * $zoom; $outH = $ch * $zoom
$crop = New-Object System.Drawing.Bitmap($outW, $outH)
$cg = [System.Drawing.Graphics]::FromImage($crop)
$cg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$cg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$cg.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,$outW,$outH)), (New-Object System.Drawing.Rectangle($cx,$cy,$cw,$ch)), [System.Drawing.GraphicsUnit]::Pixel)
$cg.Dispose(); $bmp.Dispose()
$out = Join-Path $PSScriptRoot '..\..\title_btn2.png'
$crop.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose()
Write-Host "saved title_btn2"