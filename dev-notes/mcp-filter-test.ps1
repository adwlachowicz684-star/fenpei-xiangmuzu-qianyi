# MCP tool-toggle filter end-to-end test (ASCII only)
# 1) backup + modify config: disable capture_screen / capture_window
# 2) start MCP server, verify tools/list excludes disabled tools, tools/call errors
# 3) restore config
$ErrorActionPreference = 'Stop'
$projRoot = Split-Path -Parent $PSScriptRoot
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$bak = "$cfg.bak"

# 1) backup + write disabled config
Copy-Item $cfg $bak -Force
$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $c.PSObject.Properties['mcpTools']) { $c | Add-Member -NotePropertyName mcpTools -NotePropertyValue ([ordered]@{}) }
$mt = $c.mcpTools
foreach ($k in @('capture_screen','capture_window')) {
    if (-not $mt.PSObject.Properties[$k]) { $mt | Add-Member -NotePropertyName $k -NotePropertyValue $false }
    else { $mt.$k = $false }
}
$c | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
Write-Host '[1] config updated: disabled capture_screen/capture_window'

# 2) start MCP server and send JSON-RPC
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.Arguments = '--mcp'
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.CreateNoWindow = $true
$p = [System.Diagnostics.Process]::Start($psi)

function Send-Rpc([string]$json) {
    $p.StandardInput.WriteLine($json)
    $p.StandardInput.Flush()
    $sb = New-Object System.Text.StringBuilder
    $depth = 0
    do {
        $line = $p.StandardOutput.ReadLine()
        if ($null -eq $line) { break }
        [void]$sb.AppendLine($line)
        $depth += ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)
    } while ($depth -gt 0)
    return $sb.ToString()
}

$init = Send-Rpc '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
Write-Host "[init] $init"

$list = Send-Rpc '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$tools = ($list | ConvertFrom-Json).result.tools.name
Write-Host "[tools/list] count=$($tools.Count)"
$hasScreen = $tools -contains 'capture_screen'
$hasWindow = $tools -contains 'capture_window'
Write-Host "[tools/list] capture_screen present=$hasScreen capture_window present=$hasWindow"
if ($hasScreen -or $hasWindow) { Write-Host '[FAIL] disabled tool still in tools/list'; exit 1 }

$call = Send-Rpc '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"capture_screen","arguments":{}}}'
Write-Host "[tools/call capture_screen] $call"
if ($call -notmatch '"error"') { Write-Host '[FAIL] calling disabled tool did not error'; exit 1 }

$call2 = Send-Rpc '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"get_status","arguments":{}}}'
Write-Host "[tools/call get_status] head=$($call2.Substring(0, [Math]::Min(80, $call2.Length)))"
if ($call2 -notmatch '"result"') { Write-Host '[FAIL] enabled tool call failed'; exit 1 }

$p.StandardInput.Close()
$p.WaitForExit(5000)
Write-Host '[2] e2e verification PASSED'

# 3) restore config
Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Write-Host '[3] config restored'
