# Open mind map, screenshot, list buttons (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32N {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$projRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $projRoot 'dev-notes\shots'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$proc = Get-Process -Name "分配项目组" | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle
[W32N]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Host "BUTTON_COUNT: $($btns.Count)"
$target = $null
foreach ($b in $btns) {
    $n = $b.Current.Name
    $h = $b.Current.HelpText
    if ($n -like '*mindmap*' -or $h -like '*mindmap*') { $target = $b; Write-Host "FOUND: name=[$n] help=[$h]" }
}
if (-not $target) {
    Write-Host 'mindmap button not found; buttons:'
    foreach ($b in $btns) { Write-Host "  [$($b.Current.Name)] help=[$($b.Current.HelpText)]" }
    exit 1
}
$invoke = $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Host 'INVOKED mindmap'
Start-Sleep -Seconds 8

# screenshot window
$wr = New-Object W32N+RECT
[W32N]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left
$h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($wr.Left, $wr.Top, 0, 0, $bmp.Size)
$out = Join-Path $outDir 'note-panel-1-mindmap.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved $out"
