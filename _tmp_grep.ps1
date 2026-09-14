$ErrorActionPreference = 'Stop'
$target = 'E:\_project\AIProject_项目\工具开发\分配项目组迁移\数据\plugins\kityminder\dist\index.html'
$patterns = 'kityminder\.Command|_commands|kity\.createClass|registerModule|var minder|window\.minder'
$m = Select-String -Path $target -Pattern $patterns
foreach ($x in $m) {
    Write-Output ('{0}: {1}' -f $x.LineNumber, $x.Line.Trim())
}
