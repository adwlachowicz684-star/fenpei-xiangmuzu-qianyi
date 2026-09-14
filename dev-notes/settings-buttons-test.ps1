# E2E test: settings panel 全选/全不选/置顶 buttons via UIAutomation (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$bak = "$cfg.bak3"

# backup config
Copy-Item $cfg $bak -Force

$proc = Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { $proc = Start-Process $exe -PassThru; Start-Sleep -Seconds 4; $proc.Refresh() }
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq 0) { Write-Host 'NO WINDOW'; exit 1 }

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)

function Find-Button([string]$name) {
    $btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
    foreach ($b in $btns) {
        if ($b.Current.Name -eq $name -or $b.Current.HelpText -eq $name) { return $b }
    }
    return $null
}

# open settings panel
$settings = Find-Button '设置'
if (-not $settings) { Write-Host '[FAIL] settings button not found'; exit 1 }
$settings.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200

function Get-LinkAgents {
    $c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
    return $c.linkAgents
}

# --- test 全选 ---
$all = Find-Button '全选'
if (-not $all) { Write-Host '[FAIL] 全选 button not found'; exit 1 }
$r = $all.Current.BoundingRectangle
Write-Host "[全选] at $($r.X),$($r.Y) size $($r.Width)x$($r.Height)"
$all.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1200
$la = Get-LinkAgents
$trueCount = ($la.PSObject.Properties | Where-Object { $_.Value -eq $true }).Count
$falseCount = ($la.PSObject.Properties | Where-Object { $_.Value -eq $false }).Count
Write-Host "[全选] true=$trueCount false=$falseCount"
if ($trueCount -ne 16) { Write-Host '[FAIL] 全选 did not enable all 16'; exit 1 }

# --- test 全不选 ---
$none = Find-Button '全不选'
if (-not $none) { Write-Host '[FAIL] 全不选 button not found'; exit 1 }
$none.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 800
$la = Get-LinkAgents
$trueCount = ($la.PSObject.Properties | Where-Object { $_.Value -eq $true }).Count
Write-Host "[全不选] true=$trueCount"
if ($trueCount -ne 0) { Write-Host '[FAIL] 全不选 did not disable all'; exit 1 }

# --- test 置顶: click first pin button, expect linkAgentsPinned has 1 entry ---
$pin = $null
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
foreach ($b in $btns) {
    if ($b.Current.HelpText -eq '置顶 / 取消置顶') { $pin = $b; break }
}
if (-not $pin) { Write-Host '[FAIL] pin button not found'; exit 1 }
$pin.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 800
$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$pinned = @($c.linkAgentsPinned)
Write-Host "[置顶] pinned=$($pinned -join ',') count=$($pinned.Count)"
if ($pinned.Count -lt 1) { Write-Host '[FAIL] pin did not record'; exit 1 }

Write-Host 'E2E settings-buttons verification PASSED'

# restore config
Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Get-Process -Name "分配项目组" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'config restored, app closed'
