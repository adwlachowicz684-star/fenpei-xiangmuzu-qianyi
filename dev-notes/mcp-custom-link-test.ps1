# MCP custom-link-name end-to-end test (ASCII only)
# 1) backup + inject customLinkAgents [.foo, .bar]
# 2) start MCP server, create_link -> verify .foo/.bar junctions created
# 3) list_links verify -> remove_link cleanup
# 4) restore config
$ErrorActionPreference = 'Stop'
$projRoot = Split-Path -Parent $PSScriptRoot
$cfg = Join-Path $projRoot '数据\分配项目组-config.json'
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$bak = "$cfg.bak"

$tmp = Join-Path $env:TEMP 'fpx-custom-link-test'
$proj = Join-Path $tmp 'proj'
$grp  = Join-Path $tmp 'grp'
New-Item -ItemType Directory -Force -Path $proj, $grp | Out-Null

# 1) backup + inject customLinkAgents
Copy-Item $cfg $bak -Force
$c = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $c.PSObject.Properties['customLinkAgents']) { $c | Add-Member -NotePropertyName customLinkAgents -NotePropertyValue @('.foo','.bar') }
else { $c.customLinkAgents = @('.foo','.bar') }
$c | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
Write-Host '[1] config injected customLinkAgents=[.foo,.bar]'

# 2) start MCP server
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
Write-Host "[init] ok=$($init -match 'result')"

$esc = { param($s) $s.Replace('\','\\').Replace('"','\"') }
$createJson = '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_link","arguments":{"project":"' + (& $esc $proj) + '","group":"' + (& $esc $grp) + '"}}}'
$create = Send-Rpc $createJson
Write-Host "[create_link] $create"
if ($create -notmatch '"result"') { Write-Host '[FAIL] create_link errored'; exit 1 }

# verify junctions physically exist
$fooOk = (Get-Item (Join-Path $proj '.foo') -ErrorAction SilentlyContinue).Attributes -band [IO.FileAttributes]::ReparsePoint
$barOk = (Get-Item (Join-Path $proj '.bar') -ErrorAction SilentlyContinue).Attributes -band [IO.FileAttributes]::ReparsePoint
Write-Host "[fs] .foo junction=$([bool]$fooOk) .bar junction=$([bool]$barOk)"
if (-not $fooOk -or -not $barOk) { Write-Host '[FAIL] custom junction not created on disk'; exit 1 }

$list = Send-Rpc '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_links","arguments":{}}}'
Write-Host "[list_links] has .foo=$($list -match '\.foo') has .bar=$($list -match '\.bar')"
if ($list -notmatch '\.foo' -or $list -notmatch '\.bar') { Write-Host '[FAIL] list_links missing custom names'; exit 1 }

$removeJson = '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"remove_link","arguments":{"project":"' + (& $esc $proj) + '"}}}'
$remove = Send-Rpc $removeJson
Write-Host "[remove_link] $remove"
if ($remove -notmatch '"result"') { Write-Host '[FAIL] remove_link errored'; exit 1 }

$fooGone = -not (Test-Path (Join-Path $proj '.foo'))
$barGone = -not (Test-Path (Join-Path $proj '.bar'))
Write-Host "[fs] after remove .foo gone=$fooGone .bar gone=$barGone"
if (-not $fooGone -or -not $barGone) { Write-Host '[FAIL] custom junction not removed'; exit 1 }

$p.StandardInput.Close()
$p.WaitForExit(5000)
Write-Host '[2] e2e custom-link-name verification PASSED'

# 3) cleanup temp dirs + restore config
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Copy-Item $bak $cfg -Force
Remove-Item $bak -Force
Write-Host '[3] config restored, temp cleaned'
