foreach($nm in @(20,40,60)){
    Set-AlertRange $nm
    $frame=[pscustomobject]@{state='LIVE';source='TEST';contacts=@(
        [pscustomobject]@{id='edge';range_m=($nm*1852.0)},
        [pscustomobject]@{id='outside';range_m=($nm*1852.0+1)},
        [pscustomobject]@{id='bearing-only'})}
    $limited=Limit-RwrFrame $frame
    if($limited.contacts.Count -ne 2 -or @($limited.contacts|Where-Object {$_.id -eq 'outside'}).Count){throw 'RWR range boundary or unknown-distance retention failed'}
    if(-not (Test-AlertMissileRange ([pscustomobject]@{ned=@{x=($nm*1852.0);y=0;z=0}}) $null)){throw 'Missile range boundary missing'}
    if(Test-AlertMissileRange ([pscustomobject]@{ned=@{x=($nm*1852.0+1);y=0;z=0}}) $null){throw 'Missile outside range accepted'}
}
Set-AlertRange 20
$view=[pscustomobject]@{ownship=@{x=0;y=1000;z=0};camera=@{p=@{x=5;y=1001;z=0}}}
if((Get-CockpitViewState $view $true) -ne 'NEAR_COCKPIT'){throw 'Near cockpit hidden'}
$view.camera.p.x=50
if((Get-CockpitViewState $view $true) -ne 'EXTERNAL'){throw 'External camera not rejected'}
if((Get-CockpitViewState $view $false) -ne 'UNKNOWN' -or (Get-CockpitViewState $null $true) -ne 'UNKNOWN'){throw 'Stale or missing camera treated as cockpit'}
$c=Load-Xaml 'Controls.xaml';$c.FindName('CockpitOnly').IsChecked=$false;$c.FindName('AlertRangeNm').Value=60
$path=Join-Path $env:TEMP ('fox-view-range-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    Save-HudSettings $c $path;$r=Load-Xaml 'Controls.xaml';Load-HudSettings $r $path
    if($r.FindName('CockpitOnly').IsChecked -or $r.FindName('AlertRangeNm').Value -ne 60){throw 'Range/view settings not restored'}
    [IO.File]::WriteAllText($path,'{"version":1,"values":{"DatalinkRangeNm":30}}')
    $r=Load-Xaml 'Controls.xaml';Load-HudSettings $r $path
    if([int]$r.FindName('DatalinkRange').SelectedValue -ne 40){throw 'Old 30 NM setting not migrated to 40 NM'}
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
Write-Output 'PASS: 20/40/60 NM RWR/missile boundaries, unknown-distance retention, cockpit proximity/stale handling, setting persistence and 30-to-40 migration'
