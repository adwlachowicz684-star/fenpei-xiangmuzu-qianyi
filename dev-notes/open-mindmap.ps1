# Fresh launch, open mindmap via InvokePattern, verify alive, PrintWindow screenshot (UTF8 BOM)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32M4 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
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

$projRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $projRoot 'dev-notes\shots'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$exe = Join-Path $projRoot 'dist\分配项目组.exe'

# kill any existing instance
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

# fresh launch
$proc = Start-Process $exe -PassThru
Start-Sleep -Seconds 6
$proc.Refresh()
$hwnd = $proc.MainWindowHandle
Write-Host "PID=$($proc.Id) HWND=$hwnd"
if ($hwnd -eq 0) { Write-Host 'NO MAIN WINDOW'; exit 1 }

[W32M4]::ShowWindow($hwnd, 3) | Out-Null
[W32M4]::ForceFront($hwnd)
Start-Sleep -Milliseconds 600

# open mindmap via InvokePattern
$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$target = $null
foreach ($b in $btns) {
    $h = $b.Current.HelpText
    if ($h -like '*思维导图*') { $target = $b; break }
}
if (-not $target) { Write-Host 'mindmap button not found'; exit 1 }
$invoke = $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Host 'INVOKED mindmap launcher'
Start-Sleep -Seconds 8

# verify alive
$alive = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
if (-not $alive) { Write-Host 'APP EXITED after mindmap open'; exit 1 }
Write-Host 'APP ALIVE after mindmap open'

# PrintWindow screenshot
$wr = New-Object W32M4+RECT
[W32M4]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left; $h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W32M4]::PrintWindow($hwnd, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$out = Join-Path $outDir 'note-panel-1-mindmap.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved $out"
