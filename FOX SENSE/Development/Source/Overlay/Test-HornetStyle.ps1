foreach($pair in @(@('SA10_5V55R','5V55'),@('5V55R','5V55'),@('S-300 48N6E2','48N6'),@('AIM_120C','AIM-120C'),@('R_27ER','R-27ER'),@('5V28','5V28'),@('unknown','M'),@('SA-10','M'))){
    if((Get-ShortMissileName $pair[0]) -ne $pair[1]){throw ('Missile short name failed: '+$pair[0])}
}
$broken=New-HornetMissileShape $false
$solid=New-HornetMissileShape $true
if($broken.Tag -ne 'Detected' -or $solid.Tag -ne 'Inbound' -or $broken.Data.ToString() -eq $solid.Data.ToString()){throw 'Missile warning geometry states mixed'}
$script:dlFrame=[pscustomobject]@{own_heading=([Math]::PI*1.5);flight=@{ias=177.49;altitude=1908.048;aoa=3.1;mach=0.58;g=1}}
$script:dlLast=[datetime]::UtcNow
Update-HornetFlightData
if($hudWindow.FindName('OwnHeading').Text -ne 'HDG 270' -or $hudWindow.FindName('OwnAltitude').Text -ne '6260' -or $hudWindow.FindName('OwnSpeed').Text -ne '345'){throw 'Flight readout conversion failed'}
$script:dlFrame=[pscustomobject]@{own_heading=0};Update-HornetFlightData
if($hudWindow.FindName('OwnSpeed').Text -or $hudWindow.FindName('SpeedBox').Visibility -ne 'Collapsed'){throw 'Missing speed fabricated a value'}
$script:dlLast=[datetime]::UtcNow.AddSeconds(-3);Update-HornetFlightData
if($hudWindow.FindName('FlightData').Visibility -ne 'Collapsed'){throw 'Stale flight readouts retained'}
$script:incomingSamples=@{test=@{Incoming=$true}};$script:jesterMissileLast=[datetime]::UtcNow
$script:incomingMarkerLast=[datetime]::UtcNow
$script:jesterMissileFrame=[pscustomobject]@{state='AWARENESS';missiles=@()};$script:modernRwrEnabled=$false
if(-not (Test-MissileMarkerInbound 'test')){throw 'Confirmed incoming marker failed'}
$script:jesterMissileLast=[datetime]::UtcNow.AddSeconds(-3)
$script:incomingMarkerLast=[datetime]::UtcNow.AddSeconds(-3)
if(Test-MissileMarkerInbound 'test'){throw 'Stale missile remained solid'}
$script:incomingSamples=@{}
if(@($hudWindow.FindName('FlightData').Children|Where-Object {$_ -is [Windows.Shapes.Path]}).Count){throw 'Unrequested helmet center reticle retained'}
$datalinkCheckbox=(Load-Xaml 'Controls.xaml').FindName('DatalinkEnabled');$datalinkCheckbox.IsChecked=$true
$script:aircraftSize=1
$camera=@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};up=@{x=0;y=1;z=0};right=@{x=0;y=0;z=1}}
Set-DatalinkFrame ([pscustomobject]@{camera=$camera;own_heading=0;ownship=@{x=0;y=0;z=0};tracks=@(@{identity='HOSTILE';age_s=0;aircraft_type='F-16C_50';p=@{x=1000;y=0;z=100}})})
Draw-Datalink
if(@($trackCanvas.Children|Where-Object {$_ -is [Windows.Controls.TextBlock] -and $_.Text -eq 'F-16'}).Count -ne 1){throw 'Helmet aircraft short label missing'}
Write-Output 'PASS: Hornet flight readouts, missing/stale data, shared short missile names, detected/inbound geometry and stale incoming state'
