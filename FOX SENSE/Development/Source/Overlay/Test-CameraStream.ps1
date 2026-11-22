$world=[pscustomobject]@{sequence=1;state='LIVE_POSITIONS';camera=@{p=@{x=0;y=1000;z=0}};ownship=@{x=0;y=1000;z=0};tracks=@([pscustomobject]@{id='retained';identity='HOSTILE';source='world_export';age_s=0;p=@{x=1000;y=1000;z=0}})}
Set-DatalinkFrame $world
$line='F4CAM_V1|{"sequence":2,"state":"LIVE_POSITIONS","camera":{"p":{"x":1,"y":1001,"z":2}},"ownship":{"x":0,"y":1000,"z":0},"flight":{"ias":200},"own_heading":1}'
$packet=ConvertFrom-DatalinkLine $line 'F4CAM_V1|'
if($null -eq $packet){throw 'Camera-only packet rejected'}
Set-CameraFrame $packet
if($script:dlFrame.tracks.Count -ne 1 -or $script:dlFrame.tracks[0].id -ne 'retained' -or $script:dlFrame.camera.p.y -ne 1001 -or $script:dlFrame.flight.ias -ne 200){throw 'Camera update lost world tracks or flight data'}
$script:dlFrame.TrackReceivedUtc=[datetime]::UtcNow.AddSeconds(-4)
Set-CameraFrame $packet
if((Get-DatalinkWorldAge) -lt 3.9 -or ([datetime]::UtcNow-$script:dlLast).TotalSeconds -gt 0.1){throw 'Fresh camera incorrectly refreshed stale world data'}
$packet=ConvertFrom-DatalinkLine ($line.Replace('"sequence":2','"sequence":0').Replace('"y":1001','"y":2000')) 'F4CAM_V1|';Set-CameraFrame $packet
if($script:dlFrame.camera.p.y -eq 2000){throw 'Old camera sequence replaced newer pose'}
Write-Output 'PASS: 60 Hz camera-only packets preserve tracks, refresh flight data, reject old poses and do not freshen stale world observations'
