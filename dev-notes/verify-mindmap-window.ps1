Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeIn6 {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lp);
}
"@

$exe = "e:\_project\AIProject_项目\工具开发\分配项目组迁移\dist\分配项目组.exe"
$p = Start-Process -FilePath $exe -PassThru
Start-Sleep -Seconds 5

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
if ($null -eq $win) { Write-Host "NO_WINDOW"; Stop-Process -Id $p.Id -Force; exit 1 }

$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$target = $null
foreach ($b in $btns) { if ($b.Current.HelpText -match "独立窗口") { $target = $b; break } }
if ($null -eq $target) { Write-Host "NO_TARGET_BTN"; Stop-Process -Id $p.Id -Force; exit 1 }

$invoke = $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Host "INVOKED"
Start-Sleep -Seconds 8

# 找到 MindMapWindow 的 HWND
$mmHwnd = $null
$cb = [NativeIn6+EnumWindowsProc]{
    param($hWnd, $lp)
    $pid2 = 0
    [NativeIn6]::GetWindowThreadProcessId($hWnd, [ref]$pid2) | Out-Null
    if ($pid2 -eq $p.Id -and [NativeIn6]::IsWindowVisible($hWnd)) {
        $sb = New-Object System.Text.StringBuilder 256
        [NativeIn6]::GetWindowText($hWnd, $sb, 256) | Out-Null
        if ($sb.ToString() -like "*思维导图*") { $script:mmHwnd = $hWnd; return $false }
    }
    return $true
}
[NativeIn6]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($null -eq $mmHwnd) { Write-Host "NO_MINDMAP_WINDOW"; Stop-Process -Id $p.Id -Force; exit 1 }
Write-Host "MINDMAP_HWND: $mmHwnd"

# 从 HWND 获取 AutomationElement
$mmEl = [System.Windows.Automation.AutomationElement]::FromHandle($mmHwnd)
Write-Host "MM_NAME: $($mmEl.Current.Name)"

# 遍历 MindMapWindow 内所有按钮，列出 help text
$mmBtns = $mmEl.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Host "MM_BUTTON_COUNT: $($mmBtns.Count)"
$i = 0
foreach ($b in $mmBtns) {
    $i++
    $n = $b.Current.Name
    $h = $b.Current.HelpText
    Write-Host ("  MM_BTN[{0}] name=[{1}] help=[{2}]" -f $i, $n, $h)
}

Stop-Process -Id $p.Id -Force
Write-Host "DONE"
