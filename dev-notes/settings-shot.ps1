# Launch app, click Settings button via UIAutomation, screenshot (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32S {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$proc = Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) {
    $proc = Start-Process $exe -PassThru
    Start-Sleep -Seconds 4
    $proc.Refresh()
}
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq 0) { Write-Host 'NO WINDOW'; exit 1 }
[W32S]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$settings = $null
foreach ($b in $btns) {
    $n = $b.Current.Name
    $h = $b.Current.HelpText
    if ($n -eq '设置' -or $h -eq '设置') { $settings = $b; break }
}
if (-not $settings) {
    Write-Host 'Settings button not found; buttons:'
    foreach ($b in $btns) { Write-Host "  name=[$($b.Current.Name)] help=[$($b.Current.HelpText)]" }
    exit 1
}
$invoke = $settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Host 'invoked Settings'
Start-Sleep -Milliseconds 900

$wr = New-Object W32S+RECT
[W32S]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left
$h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($wr.Left, $wr.Top, 0, 0, $bmp.Size)
$out = Join-Path $projRoot '界面截图_设置面板_3倍全选置顶.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved $out"
