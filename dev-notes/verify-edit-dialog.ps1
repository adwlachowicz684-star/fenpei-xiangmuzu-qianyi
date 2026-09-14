# Verify: add row vendor input + double-click edit dialog (rename/vendor/remark/pin/dot)
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
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    [DllImport("user32.dll")] public static extern bool GetSystemMetrics(int nIndex);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint INPUT_MOUSE = 0;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_ABSOLUTE = 0x8000;
    public const uint MOUSEEVENTF_MOVE = 0x0001;
    public static void ForceFront(IntPtr h) {
        SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        SetForegroundWindow(h);
        SetWindowPos(h, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }
    public static void MoveTo(int x, int y) {
        int sw = System.Windows.Forms.Screen.PrimaryScreen.Bounds.Width;
        int sh = System.Windows.Forms.Screen.PrimaryScreen.Bounds.Height;
        int ax = (int)((x * 65535) / (sw - 1));
        int ay = (int)((y * 65535) / (sh - 1));
        INPUT[] inp = new INPUT[1];
        inp[0].type = INPUT_MOUSE;
        inp[0].mi.dx = ax; inp[0].mi.dy = ay;
        inp[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void ClickAt(int x, int y) {
        MoveTo(x, y);
        System.Threading.Thread.Sleep(80);
        INPUT[] inp = new INPUT[2];
        inp[0].type = INPUT_MOUSE; inp[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        inp[1].type = INPUT_MOUSE; inp[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
        SendInput(2, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void DoubleClick(int x, int y) {
        ClickAt(x, y);
        System.Threading.Thread.Sleep(70);
        ClickAt(x, y);
    }
}
"@

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$bak = "$cfg.bakE"
Copy-Item $cfg $bak -Force

Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
$proc = Start-Process $exe -PassThru
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    $proc.Refresh()
    if ($proc.MainWindowHandle -ne 0) { break }
}
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq 0) { Write-Host '[FAIL] no main window'; exit 1 }
[W32E]::ShowWindow($hwnd, 3) | Out-Null
[W32E]::ForceFront($hwnd)
Start-Sleep -Milliseconds 800

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$cbCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)
$editCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)

# open settings
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$settings = $null
foreach ($b in $btns) { if ($b.Current.Name -eq '设置' -or $b.Current.HelpText -eq '设置') { $settings = $b; break } }
if (-not $settings) { Write-Host '[FAIL] settings not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

# verify 3 edit fields (链接名 / 厂商 / 备注)
$edits = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
Write-Host "edit fields count: $($edits.Count) (expected >= 3)"
if ($edits.Count -lt 3) { Write-Host '[FAIL] not enough edit fields'; exit 1 }

# add custom item with vendor
$vp0 = $edits[0].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
$vp0.SetValue('testvendor')
$vp1 = $edits[1].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
$vp1.SetValue('测试厂商')
Start-Sleep -Milliseconds 300
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$addBtn = $null
foreach ($b in $btns) { if ($b.Current.Name -eq '添加') { $addBtn = $b; break } }
if (-not $addBtn) { Write-Host '[FAIL] 添加 button not found'; exit 1 }
$addBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 800

# verify config after add
$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$hasName = $c.customLinkAgents -contains '.testvendor'
$vendorVal = $c.linkAgentVendors.'.testvendor'
Write-Host "customLinkAgents has .testvendor: $hasName ; vendor: $vendorVal"
if ($hasName -and $vendorVal -eq '测试厂商') { Write-Host '[PASS] add with vendor OK' }
else { Write-Host '[FAIL] add with vendor wrong'; exit 1 }

# find the new item by its Text element (checkbox content is a StackPanel, UIA name is empty)
$textCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
$texts = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $textCond)
$item = $null
foreach ($t in $texts) { if ($t.Current.Name -match 'testvendor') { $item = $t; break } }
if (-not $item) {
    Write-Host '[FAIL] new item text not found; texts:'
    foreach ($t in $texts) { Write-Host "  [$($t.Current.Name)]" }
    exit 1
}
Write-Host "item text found: [$($item.Current.Name)]"
$r = $item.Current.BoundingRectangle
$cx = [int]($r.X + $r.Width / 2)
$cy = [int]($r.Y + $r.Height / 2)
Write-Host "item rect: x=$($r.X) y=$($r.Y) w=$($r.Width) h=$($r.Height) -> click ($cx,$cy)"
[W32E]::ForceFront($hwnd)
Start-Sleep -Milliseconds 400
[W32E]::DoubleClick($cx, $cy)
Start-Sleep -Milliseconds 1500

# edit dialog should now be open (a new window owned by main). Find it.
$dlg = $null
foreach ($w in [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) {
    if ($w.Current.ClassName -eq 'HwndWrapper' -and $w.Current.Name -match '编辑链接名') { $dlg = $w; break }
}
if (-not $dlg) {
    # fallback: any new top-level window
    foreach ($w in [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($w.Current.Name -match '编辑') { $dlg = $w; break }
    }
}
if (-not $dlg) {
    Write-Host '[FAIL] edit dialog not found; top-level windows:'
    foreach ($w in [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) {
        Write-Host "  class=[$($w.Current.ClassName)] name=[$($w.Current.Name)]"
    }
    exit 1
}
Write-Host "edit dialog found: [$($dlg.Current.Name)]"

$dEdits = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
$dCbs = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cbCond)
Write-Host "dialog edit fields: $($dEdits.Count) (expected 3: 文件夹名/文件名/备注); checkboxes: $($dCbs.Count) (expected 2: 前置点/置顶)"
if ($dEdits.Count -lt 3 -or $dCbs.Count -lt 2) { Write-Host '[FAIL] dialog fields missing'; exit 1 }

# verify initial values
$nameVal = $dEdits[0].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
$vendorVal2 = $dEdits[1].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
Write-Host "dialog 文件夹名=[$nameVal] 文件名=[$vendorVal2]"
if ($nameVal -ne '.testvendor' -or $vendorVal2 -ne '测试厂商') { Write-Host '[FAIL] dialog initial values wrong'; exit 1 }

# edit: rename to testvendor2, vendor to 厂商2
$dEdits[0].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue('testvendor2')
$dEdits[1].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue('厂商2')
Start-Sleep -Milliseconds 300
$dbtns = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$okBtn = $null
foreach ($b in $dbtns) { if ($b.Current.Name -eq '确定') { $okBtn = $b; break } }
if (-not $okBtn) { Write-Host '[FAIL] 确定 button not found'; exit 1 }
$okBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 800

# verify config after edit
$c2 = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$hasNew = $c2.customLinkAgents -contains '.testvendor2'
$hasOld = $c2.customLinkAgents -contains '.testvendor'
$newVendor = $c2.linkAgentVendors.'.testvendor2'
Write-Host "after edit: has .testvendor2=$hasNew ; has .testvendor=$hasOld ; vendor=$newVendor"
if ($hasNew -and -not $hasOld -and $newVendor -eq '厂商2') { Write-Host '[PASS] edit rename+vendor OK' }
else { Write-Host '[FAIL] edit not applied correctly'; exit 1 }

Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
