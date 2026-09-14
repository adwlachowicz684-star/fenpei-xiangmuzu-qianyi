# Screenshot the title bar around the tray button. (ASCII only)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$proc = Get-Process | Where-Object { $_.Path -and $_.Path -like '*dist*' -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Host 'NO WINDOW'; exit 1 }
$hwnd = $proc.MainWindowHandle

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$list = @(); foreach ($b in $btns) { $list += ,$b }
$tray = $list[2]
$r = $tray.Current.BoundingRectangle
Write-Host ("tray btn rect=" + $r.X + "," + $r.Y + " " + $r.Width + "x" + $r.Height)

# capture the raw region first (normal size)
$W = [int]$r.Width + 60
$H = [int]$r.Height + 60
$x = [int]$r.X - 30
$y = [int]$r.Y - 30
$raw = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($raw)
$g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($W, $H)))
$g.Dispose()

$zoom = 6
$outW = $W * $zoom; $outH = $H * $zoom
$bmp = New-Object System.Drawing.Bitmap($outW, $outH)
$g2 = [System.Drawing.Graphics]::FromImage($bmp)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($raw, 0, 0, $outW, $outH)
$g2.Dispose(); $raw.Dispose()
$out = Join-Path $PSScriptRoot '..\..\title_tray_btn.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "saved title_tray_btn"