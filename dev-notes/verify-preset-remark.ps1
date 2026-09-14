# Verify: double-click preset -> dialog -> type remark -> OK -> persist (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32E {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
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
}
"@
$LEFTDOWN = 0x02; $LEFTUP = 0x04

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$bak = "$cfg.bak7"
Copy-Item $cfg $bak -Force

Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$proc = Start-Process $exe -PassThru
Start-Sleep -Seconds 4
$proc.Refresh()
$hwnd = $proc.MainWindowHandle
[W32E]::ShowWindow($hwnd, 9) | Out-Null
[W32E]::ForceFront($hwnd)
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

# double-click -> dialog opens, textbox focused
[W32E]::SetCursorPos($ix, $iy) | Out-Null
Start-Sleep -Milliseconds 300
[W32E]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32E]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 100
[W32E]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32E]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 800

# paste remark via clipboard + Ctrl+V, then Enter to confirm
[System.Windows.Forms.Clipboard]::SetText('预设备注测试')
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('^v')
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds 1000

# screenshot main window (dialog should be closed, remark shown on item)
$wr = New-Object W32E+RECT
[W32E]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W32E]::PrintWindow($hwnd, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$bmp.Save((Join-Path $projRoot '界面截图_预设备注双击.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host 'shot saved'

# verify config persisted
$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$remarkVal = $c.linkAgentRemarks.PSObject.Properties['.opencode'].Value
Write-Host "linkAgentRemarks['.opencode']: [$remarkVal]"
if ($remarkVal -eq '预设备注测试') {
    Write-Host '[PASS] preset remark persisted'
} else {
    Write-Host '[FAIL] preset remark not persisted'
}

Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
