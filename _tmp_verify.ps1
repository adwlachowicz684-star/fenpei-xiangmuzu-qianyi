$b = [System.IO.File]::ReadAllBytes('E:\_project\AIProject_项目\工具开发\分配项目组迁移\数据\plugins\kityminder\dist\index.html')
Write-Output ('len=' + $b.Length)
Write-Output ('bom=' + $b[0].ToString('X2') + $b[1].ToString('X2') + $b[2].ToString('X2'))
