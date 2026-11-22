if((Get-SaAircraftTypeLabel @{aircraft_type='FA-18C_hornet'}) -ne 'F/A-18' -or (Get-SaAircraftTypeLabel @{aircraft_type='MiG-29S'}) -ne 'MiG-29'){throw 'Aircraft family shortening failed'}
foreach($track in @(@{},@{aircraft_type='Unknown'},@{aircraft_type="bad`nname"},@{name='F-15';identity='HOSTILE'})){
    if(Get-SaAircraftTypeLabel $track){throw 'Aircraft type fabricated from absent/invalid data'}
}
$script:datalinkOverlayEnabled=$true;$script:saAircraftTypes=$true;$script:saRwrEnabled=$false
$f=[pscustomobject]@{state='LIVE_POSITIONS';ownship=@{x=0;y=0;z=0};own_heading=0;tracks=@(
    @{identity='FRIENDLY';source='world_export';age_s=0;aircraft_type='F-15C';p=@{x=1000;y=0;z=1000}},
    @{identity='HOSTILE';source='world_export';age_s=0;aircraft_type='Su-27';p=@{x=2000;y=0;z=2000}},
    @{identity='HOSTILE';source='world_export';age_s=0;p=@{x=3000;y=0;z=3000}})}
Set-DatalinkFrame $f;Draw-DatalinkOverlay
$labels=@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'SaAircraftType'})
if($labels.Count -ne 2 -or $labels[0].Text -ne 'F-15' -or $labels[1].Text -ne 'Su-27'){throw 'SA aircraft labels missing or incorrect'}
$script:saAircraftTypes=$false;Draw-DatalinkOverlay
if(@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'SaAircraftType'}).Count -ne 0 -or @($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'DatalinkContact'}).Count -ne 3){throw 'Type toggle affected aircraft symbols'}
$path=Join-Path $env:TEMP ('fox-types-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    $c=Load-Xaml 'Controls.xaml';$c.FindName('SaAircraftTypes').IsChecked=$false;Save-HudSettings $c $path
    $reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $path
    if($reopened.FindName('SaAircraftTypes').IsChecked){throw 'Type-label setting not preserved'}
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
$script:saAircraftTypes=$true;$script:datalinkOverlayEnabled=$false;$script:saRwrEnabled=$true
Write-Output 'PASS: explicit aircraft types only, short F/A-18/F-15/MiG/Su labels, friendly/hostile labels, unknown omitted, independent toggle and saved preference'
