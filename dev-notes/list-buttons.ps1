# List all buttons with positions to locate mindmap launcher (UTF8 BOM)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$proc = Get-Process -Name "分配项目组" | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle
$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Host "BUTTON_COUNT: $($btns.Count)"
$i = 0
foreach ($b in $btns) {
    $i++
    $r = $b.Current.BoundingRectangle
    $n = $b.Current.Name
    $h = $b.Current.HelpText
    $aid = $b.Current.AutomationId
    Write-Host ("  [{0}] name=[{1}] aid=[{2}] rect=({3},{4},{5},{6}) help=[{7}]" -f $i, $n, $aid, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height, $h)
}
