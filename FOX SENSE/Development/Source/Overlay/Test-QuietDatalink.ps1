foreach($name in @('MissileStatus','DatalinkStatus','Status','Detail','Source')){
    if($hudWindow.FindName($name).Visibility -ne 'Collapsed'){throw "Flight status text remains visible: $name"}
}
$script:saRwrEnabled=$false;$script:datalinkOverlayEnabled=$true
$datalinkCheckbox=(Load-Xaml 'Controls.xaml').FindName('DatalinkEnabled');$datalinkCheckbox.IsChecked=$false
$frame=[pscustomobject]@{state='LIVE_POSITIONS';own_heading=0;ownship=@{x=0;y=0;z=0};camera=$null;tracks=@(
    @{identity='FRIENDLY';age_s=0;p=@{x=18520;y=0;z=0}},
    @{identity='HOSTILE';age_s=0;p=@{x=-18520;y=0;z=0}})}
Set-DatalinkRange 20;Set-DatalinkFrame $frame;Draw-DatalinkOverlay
$map=$datalinkOverlayCanvas.Children[0]
if(@($map.Children|Where-Object {$_.Tag -eq 'DatalinkContact'}).Count -ne 2){throw 'SA aircraft layer depends on RWR or JHMCS checkbox'}
$own=@($map.Children|Where-Object {$_.Tag -eq 'SaOwnship'})[0]
if($own.Children.Count -ne 2){throw 'Ownship cross must use two independent lines'}
foreach($line in $own.Children){if(($line.X1+$line.X2)/2 -ne 210 -or ($line.Y1+$line.Y2)/2 -ne 210){throw 'Ownship cross is asymmetric'}}
if(@($map.Children|Where-Object {$_ -is [Windows.Controls.TextBlock] -and $_.Visibility -eq 'Visible' -and $_.Text -match 'JESTER|SOURCE|WAITING|EXPORT|DEMO|NO LIVE'}).Count){throw 'SA state footer remains visible'}
$script:saRwrEnabled=$true;$script:datalinkOverlayEnabled=$false;$datalinkCheckbox=$null
Write-Output 'PASS: quiet HUD, independent friendly/hostile SA aircraft, rear contact, optional RWR and symmetric ownship cross'
