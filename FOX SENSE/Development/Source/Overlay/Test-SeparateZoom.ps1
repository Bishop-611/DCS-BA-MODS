$testControls.FindName('CenterZoom').Value=1.2
$testControls.FindName('MissileZoom').Value=1.7
$testControls.FindName('RwrZoom').Value=0.8
Save-HudSettings $testControls $settingsFixture
$reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $settingsFixture
foreach($pair in @(@('CenterZoom',1.2),@('MissileZoom',1.7),@('RwrZoom',0.8))){if([Math]::Abs($reopened.FindName($pair[0]).Value-$pair[1]) -gt 0.001){throw 'Independent zoom persistence failed'}}
$testCamera=@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};up=@{x=0;y=1;z=0};right=@{x=0;y=0;z=1}}
$point=@{x=1000;y=100;z=100}
$script:missileProjectionZoom=1;$script:projectionScaleX=1;$script:projectionScaleY=1
$m1=Get-JesterMissileCue $testCamera $point
$a1=Get-TrackProjection $testCamera $point
$script:projectionScaleX=1.6;$script:projectionScaleY=1.6
$m2=Get-JesterMissileCue $testCamera $point
if([Math]::Abs($m1.X-$m2.X) -gt 0.001 -or [Math]::Abs($m1.Y-$m2.Y) -gt 0.001){throw 'Aircraft zoom moved missile'}
$script:projectionScaleX=1;$script:projectionScaleY=1;$script:missileProjectionZoom=1.8
$a2=Get-TrackProjection $testCamera $point
$m3=Get-JesterMissileCue $testCamera $point
if([Math]::Abs($a1.X-$a2.X) -gt 0.001 -or [Math]::Abs(($m3.X-1280)-1.8*($m1.X-1280)) -gt 0.001){throw 'Missile zoom not independent or not centered'}
$script:missileProjectionZoom=1
Write-Output 'PASS: aircraft/missile/RWR zoom saved separately; aircraft zoom does not move missiles; missile zoom does not move aircraft'
