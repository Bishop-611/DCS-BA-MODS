$script:dlFrame=[pscustomobject]@{own_heading=0;flight=@{altitude=1908.048;agl=100;aoa=20}}
$script:dlLast=[datetime]::UtcNow
Update-HornetFlightData
if($hudWindow.FindName('OwnAlpha').Text -ne ([string][char]0x03B1+'  20.0'+[char]0x00B0)){throw 'AoA degrees were converted a second time'}
if($hudWindow.FindName('OwnAltitude').Text -ne '328' -or $hudWindow.FindName('AltitudeRadarMarker').Visibility -ne 'Visible'){throw 'Low-altitude AGL/R display failed'}
foreach($height in @(152.4,200,-1,[double]::NaN,[double]::PositiveInfinity,$null)){
    $script:dlFrame.flight.agl=$height;Update-HornetFlightData
    if($hudWindow.FindName('OwnAltitude').Text -ne '6260' -or $hudWindow.FindName('AltitudeRadarMarker').Visibility -ne 'Collapsed'){throw 'Invalid or high AGL did not fall back to MSL'}
}
$script:dlFrame.flight.agl=152.399;Update-HornetFlightData
if($hudWindow.FindName('AltitudeRadarMarker').Visibility -ne 'Visible'){throw 'Below-500-foot boundary failed'}
$script:dlFrame.flight.agl=0;Update-HornetFlightData
if($hudWindow.FindName('OwnAltitude').Text -ne '0'){throw 'Zero AGL was discarded'}
$script:dlFrame.flight.aoa=4.543884;Update-HornetFlightData
if($hudWindow.FindName('OwnAlpha').Text -ne ([string][char]0x03B1+'  4.5'+[char]0x00B0)){throw 'Observed F-4 AoA sample regression failed'}
$script:dlFrame=[pscustomobject]@{flight=@{altitude=1908.048;aoa=$null}};Update-HornetFlightData
if($hudWindow.FindName('OwnAlpha').Text -or $hudWindow.FindName('AltitudeRadarMarker').Visibility -ne 'Collapsed'){throw 'Missing telemetry fabricated an AoA/R marker'}
Write-Output 'PASS: observed AoA sample and 20-degree regression, AGL 0/500-foot boundary, invalid/missing fallback and R marker clearing'
