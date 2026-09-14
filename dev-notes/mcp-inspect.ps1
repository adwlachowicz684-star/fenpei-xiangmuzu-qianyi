# Inspect MCP panel group positions via UIAutomation (ASCII only)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$proc = Get-Process -Name "分配项目组" | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$root = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)

$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
$texts = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$groups = @('基础信息','目录与选择','内容读取','链接管理','部署','截图')
foreach ($t in $texts) {
    $n = $t.Current.Name
    if ($groups -contains $n) {
        $r = $t.Current.BoundingRectangle
        Write-Host ("GROUP [{0}] x={1:N0} y={2:N0} w={3:N0} h={4:N0}" -f $n, $r.X, $r.Y, $r.Width, $r.Height)
    }
}
