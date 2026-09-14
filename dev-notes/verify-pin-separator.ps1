# Verify: pin icon hover reveal + pin separator line (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32V {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$LEFTDOWN = 0x02; $LEFTUP = 0x04

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$bak = "$cfg.bak4"
Copy-Item $cfg $bak -Force

$proc = Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { $proc = Start-Process $exe -PassThru; Start-Sleep -Seconds 4; $proc.Refresh() }
$hwnd = $proc.MainWindowHandle
[W32V]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
function Find-Button([string]$name) {
    $btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
    foreach ($b in $btns) {
        if ($b.Current.Name -eq $name -or $b.Current.HelpText -eq $name) { return $b }
    }
    return $null
}

$settings = Find-Button '设置'
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

# locate first list-item checkbox (below the two top toggles, leftmost column)
$cbCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
$cbs = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cbCond)
$first = $null
foreach ($cb in $cbs) {
    $rr = $cb.Current.BoundingRectangle
    if ($rr.Y -gt 360 -and ($null -eq $first -or $rr.X -lt $first.Current.BoundingRectangle.X)) { $first = $cb }
}
if (-not $first) { Write-Host '[FAIL] no list checkbox'; exit 1 }
$r = $first.Current.BoundingRectangle
$itemX = [int]($r.X + 20); $itemY = [int]($r.Y + $r.Height / 2)
Write-Host "first item at $($r.X),$($r.Y)"

function Save-Shot([string]$path) {
    $wr = New-Object W32V+RECT
    [W32V]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
    $w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($wr.Left, $wr.Top, 0, 0, $bmp.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

# 1) hover over first item -> pin icon should reveal
[W32V]::SetCursorPos($itemX, $itemY) | Out-Null
Start-Sleep -Milliseconds 800
Save-Shot (Join-Path $projRoot '界面截图_图钉悬浮.png')
Write-Host 'shot1 saved (hover)'

# 2) locate the revealed pin button (HelpText=置顶 / 取消置顶) and click it
$pin = $null
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
foreach ($b in $btns) {
    if ($b.Current.HelpText -eq '置顶 / 取消置顶') { $pin = $b; break }
}
if (-not $pin) { Write-Host '[FAIL] pin button not found after hover'; exit 1 }
$pr = $pin.Current.BoundingRectangle
$px = [int]($pr.X + $pr.Width / 2); $py = [int]($pr.Y + $pr.Height / 2)
Write-Host "pin at $($pr.X),$($pr.Y)"
[W32V]::SetCursorPos($px, $py) | Out-Null
Start-Sleep -Milliseconds 300
[W32V]::mouse_event($LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
[W32V]::mouse_event($LEFTUP, 0, 0, 0, [UIntPtr]::Zero) | Out-Null
Start-Sleep -Milliseconds 1000

# 3) move mouse away, shot after pin -> separator line expected
[W32V]::SetCursorPos(10, 10) | Out-Null
Start-Sleep -Milliseconds 500
Save-Shot (Join-Path $projRoot '界面截图_置顶分隔线.png')
Write-Host 'shot2 saved (after pin)'

$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "pinned in config: $($c.linkAgentsPinned -join ',')"

Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
