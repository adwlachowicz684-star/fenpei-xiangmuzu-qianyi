# 通过 stdio MCP 调用「分配项目组」工具的 capture_window 截图
$ErrorActionPreference = "Stop"

$projRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $projRoot 'dist\分配项目组.exe'
$out = Join-Path $projRoot '界面截图_MCP捕获.png'

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.Arguments = "--mcp"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardOutputEncoding = $psi.StandardOutputEncoding # (input 编码随 WriteLine 的 .NET 默认 UTF8)

$p = [System.Diagnostics.Process]::Start($psi)

function Send-Rpc([int]$id, [string]$method, [string]$paramsJson) {
    $req = '{"jsonrpc":"2.0","id":' + $id + ',"method":"' + $method + '"'
    if ($paramsJson) { $req += ',"params":' + $paramsJson }
    $req += '}'
    $p.StandardInput.WriteLine($req)
    $p.StandardInput.Flush()
    # 读取一行响应
    $line = $p.StandardOutput.ReadLine()
    return $line
}

try {
    # initialize 握手
    $init = Send-Rpc 1 "initialize" '{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"tester","version":"1.0"}}'
    Write-Host "INIT: $init"

    # list_windows 确认窗口
    $lw = Send-Rpc 2 "tools/call" '{"name":"list_windows","arguments":{"keyword":""}}'
    Write-Host "WINDOWS: $lw"

    # capture_window 截取
    $argsJson = '{"title":"分配项目组","output":"' + $out + '","bring_to_front":true}'
    $cap = Send-Rpc 3 "tools/call" '{"name":"capture_window"' + ',"arguments":' + $argsJson + '}'
    Write-Host "CAPTURE: $cap"
}
finally {
    $p.StandardInput.Close()
    if (!$p.HasExited) { $p.Kill() }
    $p.Dispose()
}