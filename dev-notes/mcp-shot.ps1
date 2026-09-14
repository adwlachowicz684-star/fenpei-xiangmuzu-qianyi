# Launch app, click MCP button via UIAutomation, screenshot (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$projRoot = Split-Path -Parent $PSScriptRoot

$proc = Get-Process -Name "分配项目组" | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle
[W32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# find MCP button via UIAutomation
$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$mcp = $null
foreach ($b in $btns) {
    $n = $b.Current.Name
    if ($n -eq 'MCP') { $mcp = $b; break }
}
if (-not $mcp) {
    Write-Host 'MCP button not found; buttons:'
    foreach ($b in $btns) { Write-Host "  [$($b.Current.Name)]" }
    exit 1
}
$r = $mcp.Current.BoundingRectangle
$cx = [int]($r.X + $r.Width / 2)
$cy = [int]($r.Y + $r.Height / 2)
Write-Host "MCP button at $($r.X),$($r.Y) size $($r.Width)x$($r.Height) center $cx,$cy"
$invoke = $mcp.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Host 'invoked MCP'
Start-Sleep -Milliseconds 800

# screenshot window
$wr = New-Object W32+RECT
[W32]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left
$h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($wr.Left, $wr.Top, 0, 0, $bmp.Size)
$out = Join-Path $projRoot '界面截图_MCP面板2列.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved $out"
