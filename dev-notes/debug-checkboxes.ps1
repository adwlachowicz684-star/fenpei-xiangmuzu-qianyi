# Debug: dump control tree of settings panel (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32DBG2 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$proc = Start-Process $exe -PassThru
Start-Sleep -Seconds 4
$proc.Refresh()
$hwnd = $proc.MainWindowHandle
[W32DBG2]::ShowWindow($hwnd, 9) | Out-Null
[W32DBG2]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800
Write-Host "hwnd=$hwnd title='$($proc.MainWindowTitle)'"

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Host "buttons before settings: $($btns.Count)"
$settings = $null
foreach ($b in $btns) { if ($b.Current.Name -eq '设置' -or $b.Current.HelpText -eq '设置') { $settings = $b; break } }
if (-not $settings) { Write-Host '[FAIL] settings not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Seconds 2

$btns2 = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Host "buttons after settings: $($btns2.Count)"
foreach ($b in $btns2) {
    if ($b.Current.Name -ne '' -or $b.Current.HelpText -ne '') {
        Write-Host "  BTN Name='$($b.Current.Name)' Help='$($b.Current.HelpText)'"
    }
}

$cbCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
$cbs = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cbCond)
Write-Host "checkboxes: $($cbs.Count)"
$i = 0
foreach ($cb in $cbs) {
    $rr = $cb.Current.BoundingRectangle
    Write-Host "  CB[$i] Name='$($cb.Current.Name)' X=$($rr.X) Y=$($rr.Y) W=$($rr.Width) H=$($rr.Height)"
    $i++
}
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
