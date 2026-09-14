# Verify: add custom link with remark + pin-on-add (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32R {
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
$bak = "$cfg.bak5"
Copy-Item $cfg $bak -Force

$proc = Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { $proc = Start-Process $exe -PassThru; Start-Sleep -Seconds 4; $proc.Refresh() }
$hwnd = $proc.MainWindowHandle
[W32R]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$cbCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
$editCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)

function Find-Button([string]$name) {
    $btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
    foreach ($b in $btns) {
        if ($b.Current.Name -eq $name -or $b.Current.HelpText -eq $name) { return $b }
    }
    return $null
}
function Save-Shot([string]$path) {
    $wr = New-Object W32R+RECT
    [W32R]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
    $w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($wr.Left, $wr.Top, 0, 0, $bmp.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

# open settings panel
$settings = Find-Button '设置'
if (-not $settings) { Write-Host '[FAIL] settings button not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

# locate the two add-row textboxes (name + remark) by their ToolTip
$edits = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
$nameBox = $null; $remarkBox = $null
foreach ($e in $edits) {
    $ht = $e.Current.HelpText
    if ($ht -like '*自动补前导点*') { $nameBox = $e }
    elseif ($ht -like '*备注*') { $remarkBox = $e }
}
if (-not $nameBox -or -not $remarkBox) { Write-Host '[FAIL] add-row textboxes not found'; exit 1 }
Write-Host "nameBox found, remarkBox found"

# fill name + remark via ValuePattern
$nameBox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue('myagent2')
Start-Sleep -Milliseconds 200
$remarkBox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue('测试备注：用于验证')
Start-Sleep -Milliseconds 200
Write-Host "nameBox value now: [$($nameBox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value)]"
Write-Host "remarkBox value now: [$($remarkBox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value)]"

# tick the pin-on-add checkbox (the one with Name=置顶)
$pinOnAdd = $null
$cbs = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cbCond)
foreach ($cb in $cbs) { if ($cb.Current.Name -eq '置顶') { $pinOnAdd = $cb; break } }
if (-not $pinOnAdd) { Write-Host '[FAIL] pin-on-add checkbox not found'; exit 1 }
$pinOnAdd.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle()
Start-Sleep -Milliseconds 300

# click 添加
$add = Find-Button '添加'
if (-not $add) { Write-Host '[FAIL] add button not found'; exit 1 }
$add.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1000

# screenshot: new item should be at top (pinned) with remark line
Save-Shot (Join-Path $projRoot '界面截图_自定义备注置顶.png')
Write-Host 'shot saved'

# verify config persisted (note: dict key has leading dot, use PSObject access)
$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$remarkVal = $c.linkAgentRemarks.PSObject.Properties['.myagent2'].Value
Write-Host "customLinkAgents: $($c.customLinkAgents -join ',')"
Write-Host "linkAgentsPinned: $($c.linkAgentsPinned -join ',')"
Write-Host "linkAgentRemarks['.myagent2']: [$remarkVal]"
if ($c.customLinkAgents -contains '.myagent2' -and $c.linkAgentsPinned -contains '.myagent2' -and $remarkVal -eq '测试备注：用于验证') {
    Write-Host '[PASS] remark + pin persisted'
} else {
    Write-Host '[FAIL] config not persisted correctly'
}

Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
