$datalinkCheckbox=$null
foreach($nm in @(20,40,60)){
    Set-DatalinkRange $nm
    $frame=[pscustomobject]@{state='LIVE_POSITIONS';camera=$camera;ownship=@{x=0;y=0;z=0};tracks=@(
        @{identity='FRIENDLY';age_s=0;p=@{x=($nm*1852.0);y=0;z=0}},
        @{identity='HOSTILE';age_s=0;p=@{x=($nm*1852.0+1);y=0;z=0}})}
    Set-DatalinkFrame $frame;Draw-Datalink
    if($trackCanvas.Children.Count -ne 1 -or $dlStatus.Text -notmatch "$nm NM"){throw "Range boundary/status failed: $nm NM"}
}
$testControls=Load-Xaml 'Controls.xaml'
$testPath=Join-Path $env:TEMP ('fox-range-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    foreach($nm in @(20,40,60)){
        $testControls.FindName('DatalinkRange').SelectedValue=[string]$nm
        Save-HudSettings $testControls $testPath
        $reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $testPath
        if([int]$reopened.FindName('DatalinkRange').SelectedValue -ne $nm){throw 'Range setting not restored'}
    }
    [IO.File]::WriteAllText($testPath,'{"version":1,"values":{}}')
    $reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $testPath
    if([int]$reopened.FindName('DatalinkRange').SelectedValue -ne 20){throw 'Old settings did not default to 20 NM'}
}finally{Remove-Item -LiteralPath $testPath -ErrorAction SilentlyContinue}
Set-DatalinkRange 20
Write-Output 'PASS: 20/40/60 NM inclusive boundaries, immediate status, range persistence and old-setting default'
