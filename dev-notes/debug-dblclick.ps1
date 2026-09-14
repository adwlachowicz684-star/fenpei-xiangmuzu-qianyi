# Debug: double-click handler firing check via log file (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32DBG3 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public static void ForceFront(IntPtr h) {
        SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        SetForegroundWindow(h);
        SetWindowPos(h, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }
}
"@
$LEFTDOWN = 0x02; $LEFTUP = 0x04
$log = Join-Path $env:TEMP 'fpx_dblclick.txt'
Remove-Item $log -ErrorAction SilentlyContinue

Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$proc = Start-Process $exe -PassThru
Start-Sleep -Seconds 4
$proc.Refresh()
$hwnd = $proc.MainWindowHandle
[W32DBG3]::ShowWindow($hwnd, 9) | Out-Null
[W32DBG3]::ForceFront($hwnd)
Start-Sleep -Milliseconds 800

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$cbCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$settings = $null
foreach ($b in $btns) { if ($b.Current.Name -eq '设置' -or $b.Current.HelpText -eq '设置') { $settings = $b; break } }
if (-not $settings) { Write-Host '[FAIL] settings not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

$cbs = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cbCond)
$first = $null
foreach ($cb in $cbs) {
    $rr = $cb.Current.BoundingRectangle
    if ($rr.Y -gt 400 -and ($null -eq $first -or $rr.Y -lt $first.Current.BoundingRectangle.Y)) { $first = $cb }
}
if (-not $first) { Write-Host '[FAIL] no list checkbox'; exit 1 }
$r = $first.Current.BoundingRectangle
$ix = [int]($r.X + $r.Width / 2); $iy = [int]($r.Y + $r.Height / 2)
Write-Host "item at $($r.X),$($r.Y) center $ix,$iy"

# single click first (to test ClickCount=1)
[W32DBG3]::SetCursorPos($ix, $iy) | Out-Null
Start-Sleep -Milliseconds 300
[W32DBG3]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32DBG3]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 400
Write-Host "log after single click:"
if (Test-Path $log) { Get-Content $log } else { Write-Host '  (no log)' }

# double click
[W32DBG3]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32DBG3]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 100
[W32DBG3]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32DBG3]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 800
Write-Host "log after double click:"
if (Test-Path $log) { Get-Content $log } else { Write-Host '  (no log)' }

# check for dialog window
$wins = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
$found = $false
foreach ($w in $wins) { if ($w.Current.Name -like '*备注*') { Write-Host "DIALOG FOUND: '$($w.Current.Name)'"; $found = $true } }
if (-not $found) { Write-Host 'no remark dialog window' }

# full-screen screenshot to see actual state
Add-Type -AssemblyName System.Drawing
$sw = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($sw.Width, $sw.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$bmp.Save((Join-Path $projRoot '界面截图_调试双击后.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host 'full-screen shot saved'

Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
