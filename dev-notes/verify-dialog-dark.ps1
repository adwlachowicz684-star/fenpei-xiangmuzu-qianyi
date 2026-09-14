# Verify: double-click preset -> dialog dark theme screenshot (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class W32D {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public static void ForceFront(IntPtr h) {
        SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        SetForegroundWindow(h);
        SetWindowPos(h, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }
    public static List<IntPtr> WindowsOf(uint pid) {
        var list = new List<IntPtr>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) list.Add(h);
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
"@
$LEFTDOWN = 0x02; $LEFTUP = 0x04

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$bak = "$cfg.bak8"
Copy-Item $cfg $bak -Force

Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$proc = Start-Process $exe -PassThru
Start-Sleep -Seconds 4
$proc.Refresh()
$hwnd = $proc.MainWindowHandle
[W32D]::ShowWindow($hwnd, 9) | Out-Null
[W32D]::ForceFront($hwnd)
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
Write-Host "first item at $($r.X),$($r.Y)"

# double-click -> dialog opens
[W32D]::SetCursorPos($ix, $iy) | Out-Null
Start-Sleep -Milliseconds 300
[W32D]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32D]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 100
[W32D]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32D]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 1000

# find dialog window (second visible window of the process)
$pidVal = $proc.Id
$wins = [W32D]::WindowsOf([uint32]$pidVal)
Write-Host "visible windows: $($wins.Count)"
$dlg = $null
foreach ($w in $wins) { if ($w -ne $hwnd) { $dlg = $w; break } }
if (-not $dlg) { Write-Host '[FAIL] dialog window not found'; exit 1 }
[W32D]::ForceFront($dlg)
Start-Sleep -Milliseconds 600

# screenshot the dialog window
$wr = New-Object W32D+RECT
[W32D]::GetWindowRect($dlg, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
Write-Host "dialog rect: $($wr.Left),$($wr.Top) ${w}x${h}"
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W32D]::PrintWindow($dlg, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$bmp.Save((Join-Path $projRoot '界面截图_备注对话框深色.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host 'dialog shot saved'

# close dialog via Enter (OK is default)
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds 800

# screenshot main window after close
$wr2 = New-Object W32D+RECT
[W32D]::GetWindowRect($hwnd, [ref]$wr2) | Out-Null
$w2 = $wr2.Right - $wr2.Left; $h2 = $wr2.Bottom - $wr2.Top
$bmp2 = New-Object System.Drawing.Bitmap($w2, $h2)
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$hdc2 = $g2.GetHdc()
[W32D]::PrintWindow($hwnd, $hdc2, 2) | Out-Null
$g2.ReleaseHdc($hdc2)
$bmp2.Save((Join-Path $projRoot '界面截图_备注对话框关闭后.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g2.Dispose(); $bmp2.Dispose()
Write-Host 'main shot saved'

Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
