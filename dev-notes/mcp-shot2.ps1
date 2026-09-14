# Launch app, click MCP, inspect group positions, screenshot - all in one run (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32c {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
Start-Process $exe
Start-Sleep -Seconds 5

$proc = Get-Process -Name "分配项目组" | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle
[W32c]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# click MCP via UIAutomation
$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$mcp = $null
foreach ($b in $btns) { if ($b.Current.Name -eq 'MCP') { $mcp = $b; break } }
if (-not $mcp) { Write-Host 'MCP button not found'; exit 1 }
$mcp.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Write-Host 'MCP invoked'
Start-Sleep -Milliseconds 800

# inspect group text positions
$tcond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
$texts = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tcond)
$groups = @('基础信息','目录与选择','内容读取','链接管理','部署','截图')
foreach ($t in $texts) {
    $n = $t.Current.Name
    if ($groups -contains $n) {
        $r = $t.Current.BoundingRectangle
        Write-Host ("GROUP [{0}] x={1:N0} y={2:N0}" -f $n, $r.X, $r.Y)
    }
}

# screenshot window
$wr = New-Object W32c+RECT
[W32c]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$w = $wr.Right - $wr.Left
$h = $wr.Bottom - $wr.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($wr.Left, $wr.Top, 0, 0, $bmp.Size)
$out = Join-Path $projRoot '界面截图_MCP面板2列.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved $out"
