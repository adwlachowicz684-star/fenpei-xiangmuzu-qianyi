$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore
$uri = New-Object System.Uri('file:///C:/Windows/Fonts/SegoeIcons.ttf')
$tf = New-Object System.Windows.Media.GlyphTypeface($uri)
Write-Host ("FamilyNames: " + ($tf.FamilyNames.Values -join ', '))
Write-Host ("Win32Family: " + $tf.Win32FamilyNames.Values -join ', ')
$map = $tf.CharacterToGlyphMap
$codes = @{
    'E7A7 Undo' = 0xE7A7; 'E7A6 Redo' = 0xE7A6; 'E74A Up' = 0xE74A; 'E74B Down' = 0xE74B;
    'E71B Link' = 0xE71B; 'EB9F Photo' = 0xEB9F; 'E90C Comment' = 0xE90C; 'E721 Search' = 0xE721;
    'E8A1 Expand' = 0xE8A1; 'E8A5 Document' = 0xE8A5; 'E710 Add' = 0xE710; 'E70F Edit' = 0xE70F;
    'E74D Delete' = 0xE74D; 'E70E ChevUp' = 0xE70E; 'E70D ChevDown' = 0xE70D; 'E8C8 Note' = 0xE8C8;
    'E8B9 Photo2' = 0xE8B9; 'E8BD Message' = 0xE8BD; 'E91B Picture' = 0xE91B; 'E8A0 Up2' = 0xE8A0;
    'E8A1 Down2' = 0xE8A1; 'E8A2 Undo2' = 0xE8A2; 'E8A3 Redo2' = 0xE8A3
}
foreach ($k in $codes.Keys) {
    $cp = $codes[$k]
    $has = $map.ContainsKey($cp)
    Write-Host ("{0} -> {1}" -f $k, $(if ($has) { 'OK' } else { 'MISSING' }))
}
