$script:datalinkOverlayEnabled=$true
$datalinkCheckbox=(Load-Xaml 'Controls.xaml').FindName('DatalinkEnabled')
$datalinkCheckbox.IsChecked=$false
$mapFrame=[pscustomobject]@{state='LIVE_POSITIONS';own_heading=0;ownship=@{x=0;y=0;z=0};camera=$null;tracks=@(
    @{identity='FRIENDLY';age_s=0;p=@{x=18520;y=0;z=0}},
    @{identity='HOSTILE';age_s=0;p=@{x=0;y=0;z=18520}},
    @{identity='UNKNOWN';age_s=0;p=@{x=0;y=0;z=100}})}
Set-DatalinkRange 20;Set-DatalinkFrame $mapFrame;Draw-DatalinkOverlay
$map=$datalinkOverlayCanvas.Children[0]
if(@($map.Children|Where-Object {$_.Tag -eq 'DatalinkContact'}).Count -ne 2){throw 'Map failed without camera or depended on JHMCS checkbox'}
if((New-SaContactSymbol 'FRIENDLY').Children[0].Points.Count -ne 19 -or (New-SaContactSymbol 'HOSTILE').Children[0].Points.Count -ne 3){throw 'SA friend/hostile shapes not distinct'}
$p=Get-DatalinkMapPoint $mapFrame $mapFrame.tracks[0]
if($p.X -ne 210 -or $p.Y -ne 130){throw 'Heading-up forward geometry failed'}
$mapFrame.own_heading=[Math]::PI/2
$p=Get-DatalinkMapPoint $mapFrame $mapFrame.tracks[1]
if([Math]::Abs($p.Y-130) -gt 0.01 -or [Math]::Abs($p.X-210) -gt 0.01){throw 'Map heading rotation failed'}
foreach($nm in @(20,40,60)){
    Set-DatalinkRange $nm
    $mapFrame.tracks=@(@{identity='HOSTILE';age_s=0;p=@{x=($nm*1852.0);y=0;z=0}},@{identity='HOSTILE';age_s=0;p=@{x=($nm*1852.0+1);y=0;z=0}})
    Set-DatalinkFrame $mapFrame;Draw-DatalinkOverlay
    if(@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'DatalinkContact'}).Count -ne 1){throw 'Map range boundary failed'}
}
$script:datalinkOverlayX=2140;$script:datalinkOverlayY=1020;$script:datalinkOverlayScale=2
Draw-DatalinkOverlay;$map=$datalinkOverlayCanvas.Children[0]
if($map.RenderTransform.Value.M11 -ne 2 -or [Windows.Controls.Canvas]::GetLeft($map) -gt 1720 -or [Windows.Controls.Canvas]::GetTop($map) -gt 600){throw 'Map scaled off-screen'}
$script:dlLast=[datetime]::UtcNow.AddSeconds(-3);Draw-DatalinkOverlay
if(@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'DatalinkContact'}).Count -ne 0){throw 'Map retained stale contacts'}
$script:datalinkOverlayEnabled=$false;Draw-DatalinkOverlay
if($datalinkOverlayCanvas.Children.Count -ne 0){throw 'Map checkbox failed'}
$c=Load-Xaml 'Controls.xaml';$c.FindName('ModernRwrEnabled').IsChecked=$true;$c.FindName('DatalinkOverlayEnabled').IsChecked=$true
$c.FindName('DatalinkOverlayX').Value=600;$c.FindName('DatalinkOverlayY').Value=300;$c.FindName('DatalinkOverlayScale').Value=1.6
$testPath=Join-Path $env:TEMP ('fox-map-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    Save-HudSettings $c $testPath;$reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $testPath
    if(-not $reopened.FindName('DatalinkOverlayEnabled').IsChecked -or -not $reopened.FindName('ModernRwrEnabled').IsChecked -or $reopened.FindName('DatalinkOverlayX').Value -ne 600 -or $reopened.FindName('DatalinkOverlayY').Value -ne 300 -or $reopened.FindName('DatalinkOverlayScale').Value -ne 1.6){throw 'Overlay setting persistence failed'}
}finally{Remove-Item -LiteralPath $testPath -ErrorAction SilentlyContinue}
$datalinkCheckbox=$null;$script:datalinkOverlayScale=1;$script:datalinkOverlayX=180;$script:datalinkOverlayY=880
Set-DatalinkRange 20
Write-Output 'PASS: independent datalink map, heading/range geometry, toggle, position/size persistence, scaled bounds and stale clearing'
