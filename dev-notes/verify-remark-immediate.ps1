# Verify: double-click .opencode by text position -> dialog -> paste -> OK -> display (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class W32F {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
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
$bak = "$cfg.bakD"
Copy-Item $cfg $bak -Force

$cc = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
if ($cc.linkAgentRemarks) { $cc.linkAgentRemarks.PSObject.Properties.Remove('.opencode') }
$cc | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
Write-Host 'cleared .opencode remark'

Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$proc = Start-Process $exe -PassThru
Start-Sleep -Seconds 4
$proc.Refresh()
$hwnd = $proc.MainWindowHandle
[W32F]::ShowWindow($hwnd, 3) | Out-Null
[W32F]::ForceFront($hwnd)
Start-Sleep -Milliseconds 800

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$settings = $null
foreach ($b in $btns) { if ($b.Current.Name -eq '设置' -or $b.Current.HelpText -eq '设置') { $settings = $b; break } }
if (-not $settings) { Write-Host '[FAIL] settings not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

# find the ".opencode" Text element and get its position
$textCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
$texts = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $textCond)
$opencodeText = $null
foreach ($t in $texts) { if ($t.Current.Name -eq '.opencode') { $opencodeText = $t; break } }
if (-not $opencodeText) { Write-Host '[FAIL] .opencode text not found'; exit 1 }
$r = $opencodeText.Current.BoundingRectangle
$ix = [int]($r.X + $r.Width / 2); $iy = [int]($r.Y + $r.Height / 2)
Write-Host ".opencode text at $($r.X),$($r.Y) size $($r.Width)x$($r.Height)"

# double-click on the .opencode text
[W32F]::SetCursorPos($ix, $iy) | Out-Null
Start-Sleep -Milliseconds 300
[W32F]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32F]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 100
[W32F]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32F]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 1000

# verify dialog opened (find window with title 编辑备注)
$pidVal = $proc.Id
$wins = [W32F]::WindowsOf([uint32]$pidVal)
$dlg = $null
foreach ($w in $wins) {
    if ($w -ne $hwnd) {
        $len = [W32F]::GetWindowTextLength($w)
        if ($len -gt 0) { $dlg = $w; break }
    }
}
if (-not $dlg) { Write-Host '[FAIL] dialog not found'; exit 1 }
Write-Host 'dialog found, bringing to front'
[W32F]::ForceFront($dlg)
Start-Sleep -Milliseconds 500

# paste remark via clipboard (dialog textbox auto-focused with SelectAll)
[System.Windows.Forms.Clipboard]::SetText('立即显示测试备注')
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('^v')
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds 1000

# verify remark text visible in settings panel (re-acquire root, longer wait)
Start-Sleep -Milliseconds 1500
$root2 = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$texts2 = $root2.FindAll([System.Windows.Automation.TreeScope]::Descendants, $textCond)
$uiFound = $false
foreach ($t in $texts2) { if ($t.Current.Name -match '立即显示测试备注') { $uiFound = $true; Write-Host "[UIA-FOUND] remark shown: $($t.Current.Name)" } }
if ($uiFound) { Write-Host '[PASS] remark displayed immediately' }
else { Write-Host '[FAIL] remark not displayed immediately' }

# screenshot for visual confirmation
Add-Type -AssemblyName System.Drawing
$wr = New-Object W32F+RECT
[W32F]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W32F]::PrintWindow($hwnd, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$bmp.Save((Join-Path $projRoot '界面截图_备注立即显示.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host 'shot saved'

# verify config persisted
$c2 = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$remarkVal = $c2.linkAgentRemarks.PSObject.Properties['.opencode'].Value
Write-Host "config linkAgentRemarks['.opencode']: [$remarkVal]"
if ($remarkVal -eq '立即显示测试备注') { Write-Host '[PASS] remark persisted' }
else { Write-Host '[FAIL] remark not persisted' }

Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
