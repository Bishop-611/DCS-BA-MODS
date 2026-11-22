$typeface=[Windows.Media.Typeface]::new($script:instrumentFont,[Windows.FontStyles]::Normal,[Windows.FontWeights]::Normal,[Windows.FontStretches]::Normal)
$glyph=$null
if(-not $typeface.TryGetGlyphTypeface([ref]$glyph)){throw 'Bundled instrument font failed to load'}
if($glyph.FontUri.LocalPath -notlike '*ShareTechMono-Regular.ttf'){throw 'Instrument font silently fell back to a system font'}
foreach($char in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-/.'.ToCharArray()){
 if(-not $glyph.CharacterToGlyphMap.ContainsKey([int]$char)){throw 'Bundled font missing required instrument glyph'}
}
$menu=Load-Xaml 'Controls.xaml'
if($menu.FontFamily.Source -ne 'Segoe UI' -or $menu.FindName('HideControls').FontFamily.Source -ne 'Segoe UI' -or $menu.FindName('ExitApplication').FontFamily.Source -ne 'Segoe UI'){throw 'Menu font must retain original Segoe UI'}
if($hudWindow.FindName('OwnHeading').FontFamily.Source -notlike '*Share Tech Mono'){throw 'Flight readout typography inconsistent'}
Write-Output 'PASS: private bundled HUD font resolves without system installation; menu and Hide/Exit retain original Segoe UI'
