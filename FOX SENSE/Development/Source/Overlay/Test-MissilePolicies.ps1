$script:hostileMissileMarkersOnly=$true
$script:modernRwrEnabled=$true;$script:exportMissileFrame=$null;$script:jesterMissileCache=@{}
$script:dlFrame=[pscustomobject]@{ownship=@{x=0;y=0;z=0};own_heading=0;camera=@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};right=@{x=0;y=0;z=1};up=@{x=0;y=1;z=0}}}
$script:dlLast=[datetime]::UtcNow
$script:missionFrame=[pscustomobject]@{state='SIM_RECEIVER';sequence=901;sample_time=1;ownship=@{x=0;y=0;z=0};missiles=@(
 @{id='enemy';identity='HOSTILE';inbound=$true;p=@{x=1000;y=0;z=0}},
 @{id='friend';identity='FRIENDLY';inbound=$true;p=@{x=2000;y=0;z=0}},
 @{id='unknown';identity='UNKNOWN';inbound=$false;p=@{x=3000;y=0;z=0}},
 @{id='own';identity='HOSTILE';own_launch=$true;inbound=$true;p=@{x=4000;y=0;z=0}})}
$script:missionLast=[datetime]::UtcNow
Draw-JesterMissiles
if($missileCanvas.Children.Count -ne 1 -or $script:jesterMissileCache.Count -ne 1 -or -not $script:jesterMissileCache.ContainsKey('enemy')){throw 'HUD triangles did not restrict to enemy missiles'}
$layer=New-SaMissileLayer $script:dlFrame
if(@($layer.Children|Where-Object {$_.Tag -eq 'SaMissileContact'}).Count -ne 1){throw 'SA triangles did not restrict to enemy missiles'}
$script:missionFrame.missiles[0].identity='FRIENDLY';$script:missionLast=[datetime]::UtcNow.AddMilliseconds(1)
Draw-JesterMissiles
if($missileCanvas.Children.Count -ne 0 -or $script:jesterMissileCache.Count -ne 0){throw 'Reclassified friendly retained a cached triangle'}
$script:incomingSamples=@{};$script:incomingSource='';$script:incomingPacketKey=''
$script:missionFrame.missiles=@($script:missionFrame.missiles[1]);$script:missionLast=[datetime]::UtcNow
Update-IncomingMissileAudio
$friendPacket=ConvertTo-MissilePacket $script:missionFrame
if(-not (Test-MissileAudioThreat $friendPacket.missiles[0] 'MISSION')){throw 'Friendly inbound excluded from Tone 3'}
if($script:incomingThreatActive){throw 'Tone 3 friendly change altered Tone 4 filtering'}
$script:missionFrame=$null;$script:jesterMissileCache=@{};$script:incomingSamples=@{}
Write-Output 'PASS: live policy enemy-only HUD/SA triangles, cached-friendly removal, friendly inbound allowed for Tone 3, own launch suppressed and Tone 4 unchanged'
