# Verify: add-row input labels (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32L {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$proc = Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { $proc = Start-Process $exe -PassThru; Start-Sleep -Seconds 4; $proc.Refresh() }
$hwnd = $proc.MainWindowHandle
[W32L]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
[W32L]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800

function Save-Shot([string]$path) {
    $wr = New-Object W32L+RECT
    [W32L]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
    $w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [W32L]::PrintWindow($hwnd, $hdc, 2) | Out-Null   # PW_RENDERFULLCONTENT
    $g.ReleaseHdc($hdc)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$settings = $null
foreach ($b in $btns) { if ($b.Current.Name -eq '设置' -or $b.Current.HelpText -eq '设置') { $settings = $b; break } }
if (-not $settings) { Write-Host '[FAIL] settings not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

Save-Shot (Join-Path $projRoot '界面截图_输入框标题.png')
Write-Host 'shot saved'
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
