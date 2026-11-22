$script:settingsReady=$false;$controls.FindName('DatalinkOverlayEnabled').IsChecked=$true
$controls.FindName('LaunchWarningRangeNm').Value=60
foreach($nm in @(20,40,60,20)){
 $controls.FindName('SaRwrRangeNm').Value=$nm
 Draw-DatalinkOverlay
 $title=@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'SaRangeTitle'})[0]
 if($script:markerRangeM -ne $nm*1852 -or $script:alertRangeM -ne $nm*1852 -or $title.Text -ne "SA / RWR $nm NM"){throw "Shared range failed requested=$nm SA=$($script:markerRangeM/1852) RWR=$($script:alertRangeM/1852) title=$($title.Text)"}
 if($script:launchWarningRangeM -ne 60*1852){throw 'Shared SA slider changed Launch warning'}
}
foreach($nm in @(20,40,60)){
 $controls.FindName('LaunchWarningRangeNm').Value=$nm
 if($script:launchWarningRangeM -ne $nm*1852 -or $script:markerRangeM -ne 20*1852 -or $script:alertRangeM -ne 20*1852){throw 'Launch warning slider is not independent'}
}
$script:menuAudioPlayer=[Windows.Media.MediaPlayer]::new();$script:incomingTonePlayer=[Windows.Media.MediaPlayer]::new();$script:missileTonePlayer=[Windows.Media.MediaPlayer]::new()
foreach($vol in @(0,0.35,1)){
 $controls.FindName('AudioVolume').Value=$vol
 [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background)
 foreach($p in @($script:menuAudioPlayer,$script:incomingTonePlayer,$script:missileTonePlayer)){if([Math]::Abs($p.Volume-$vol) -gt 0.001){throw "Volume requested=$vol slider=$($controls.FindName('AudioVolume').Value) global=$script:audioVolume player=$($p.Volume)"}}
}
$path=Join-Path $env:TEMP ('fox-audio-'+[guid]::NewGuid().ToString('N')+'.json')
try{
 $controls.FindName('AudioVolume').Value=0.35;Save-HudSettings $controls $path
 $restored=Load-Xaml 'Controls.xaml';Load-HudSettings $restored $path
 if($restored.FindName('LaunchWarningRangeNm').Value -ne 60 -or [Math]::Abs($restored.FindName('AudioVolume').Value-0.35) -gt 0.001){throw 'Launch warning/volume persistence failed'}
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
Write-Output 'PASS: production shared SA/RWR slider/header, independent Launch warning range, live volume 0/35/100 percent on media players and saved settings; no sound played'
foreach($nm in @(20,40,60)){
 $controls.FindName(('Range'+$nm)).RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 if($script:markerRangeM -ne $nm*1852 -or $script:alertRangeM -ne $nm*1852 -or $controls.FindName(('Range'+$nm)).Background.ToString() -ne '#FF237B9C'){throw 'Visible SA/RWR range button/state/highlight failed'}
 $controls.FindName(('LaunchRange'+$nm)).RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 if($script:launchWarningRangeM -ne $nm*1852 -or $controls.FindName(('LaunchRange'+$nm)).Background.ToString() -ne '#FF237B9C'){throw 'Visible Launch range button/highlight failed'}
}
$incomingState=$controls.FindName('IncomingAudio').IsChecked
$controls.FindName('RwrWarning').IsChecked=$false
if($script:rwrWarningEnabled -or $controls.FindName('IncomingAudio').IsChecked -ne $incomingState){throw 'Independent RWR warning switch failed'}
$controls.FindName('RwrWarning').IsChecked=$true
$controls.FindName('CenterZoom').Value=1.5;$controls.FindName('MissileZoom').Value=1.8;$controls.FindName('RwrZoom').Value=0.7
$controls.FindName('ResetAllCalibration').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
foreach($name in @('CenterZoom','MissileZoom','RwrZoom')){if($controls.FindName($name).Value -ne 1){throw 'Reset calibration did not reset all groups'}}
Write-Output 'PASS: visible three-position buttons and highlights, independent RWR warning switch, reset-all calibration; no sound played'
if($timer.Interval.TotalMilliseconds -lt (1000.0/60.0)){throw 'HUD scheduler exceeded 60 Hz cap'}
Write-Output 'PASS: HUD scheduler capped at 60 Hz'
$menuVisible=$controls.IsVisible
foreach($visible in @($true,$false,$false,$true,$true,$false,$true)){
    Set-HudWindowVisible $visible
    if($hudWindow.IsVisible -ne $visible){throw 'Native HUD window visibility transition failed'}
    if($controls.IsVisible -ne $menuVisible){throw 'HUD window visibility changed menu'}
}
if($hudWindow.ShowActivated -or $hudWindow.Focusable){throw 'HUD visibility restoration could take focus'}
Set-HudWindowVisible $false
Write-Output 'PASS: repeated native HUD hide/show restores window, preserves menu and retains passive focus settings'
$controls.FindName('DatalinkEnabled').IsChecked=$true
Set-DatalinkFrame (New-DatalinkDemo 0) $true;Draw-Datalink
$markerCount=$trackCanvas.Children.Count
$controls.FindName('FlightDataEnabled').IsChecked=$false
Update-HornetFlightData
if($hudWindow.FindName('FlightData').Visibility -ne 'Collapsed' -or $trackCanvas.Children.Count -ne $markerCount -or -not $controls.FindName('DatalinkEnabled').IsChecked){throw 'Flight-data toggle changed markers or failed to hide panel'}
$togglePath=Join-Path $env:TEMP ('fox-flight-toggle-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    Save-HudSettings $controls $togglePath
    $copy=Load-Xaml 'Controls.xaml';Load-HudSettings $copy $togglePath
    if($copy.FindName('FlightDataEnabled').IsChecked){throw 'Flight-data OFF setting did not persist'}
    [IO.File]::WriteAllText($togglePath,'{"version":1,"values":{}}')
    $copy=Load-Xaml 'Controls.xaml';Load-HudSettings $copy $togglePath
    if(-not $copy.FindName('FlightDataEnabled').IsChecked){throw 'Old settings no longer default flight data ON'}
}finally{[IO.File]::Delete($togglePath)}
$controls.FindName('FlightDataEnabled').IsChecked=$true
Update-HornetFlightData
if($hudWindow.FindName('FlightData').Visibility -ne 'Visible'){throw 'Flight-data toggle failed to restore panel'}
Write-Output 'PASS: independent flight-data switch hides/restores complete panel, preserves markers and round-trips settings; legacy default ON'
$leasePath=Join-Path $env:TEMP ('fox-heartbeat-'+[guid]::NewGuid().ToString('N')+'.active')
$savedLeasePath=$script:bridgeLeasePath;$savedPulse=$script:lastBridgePulse
try{
    $script:bridgeLeasePath=$leasePath;$script:lastBridgePulse=[datetime]::MinValue
    Update-BridgeHeartbeat
    if(-not [IO.File]::Exists($leasePath)){throw 'Bridge heartbeat was not created'}
    $stamp=[IO.File]::GetLastWriteTimeUtc($leasePath);Update-BridgeHeartbeat
    if([IO.File]::GetLastWriteTimeUtc($leasePath) -ne $stamp){throw 'Bridge heartbeat was not rate limited'}
}finally{[IO.File]::Delete($leasePath);$script:bridgeLeasePath=$savedLeasePath;$script:lastBridgePulse=$savedPulse}
Write-Output 'PASS: local bridge heartbeat creation and 1 Hz write limit'
