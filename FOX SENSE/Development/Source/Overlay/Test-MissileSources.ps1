$script:modernRwrEnabled=$true
$script:exportMissileFrame=ConvertFrom-WorldMissileLine 'F4EXPORT_MISSILES_V1|{"state":"LIVE","sequence":4,"missiles":[{"id":"export1","identity":"HOSTILE","type":"5V28","p":{"x":1000,"y":100,"z":100}}]}'
$script:exportMissileLast=[datetime]::UtcNow
$script:missionFrame=ConvertFrom-WorldMissileLine 'F4MODERN_V1|{"state":"SIM_RECEIVER","sequence":3,"ownship":{"x":0,"y":0,"z":0},"own_heading":0,"emitters":[{"type":"RPC_5N62V","symbol":"5","mode":"TRACK","p":{"x":1000,"y":0,"z":0}}],"missiles":[{"id":"mission1","identity":"HOSTILE","type":"5V28","p":{"x":1000,"y":100,"z":100}}]}' 'F4MODERN_V1|'
$script:missionLast=[datetime]::UtcNow
$script:jesterMissileFrame=[pscustomobject]@{state='AWARENESS';sequence=2;missiles=@([pscustomobject]@{id='jester1';identity='UNKNOWN';age_s=0;ned=@{x=1000;y=100;z=-100}})}
$script:jesterMissileLast=[datetime]::UtcNow
if((Get-ActiveMissileFeed).Source -ne 'EXPORT'){throw 'Export missiles not preferred'}
Set-DatalinkFrame ([pscustomobject]@{camera=$missileCamera;own_heading=0;ownship=@{x=0;y=0;z=0};tracks=@()})
Draw-JesterMissiles
if($missileCanvas.Children.Count -ne 1 -or -not $script:jesterMissileCache.ContainsKey('export1') -or $script:jesterMissileCache.ContainsKey('jester1')){throw 'Missile source coordinates mixed'}
$layer=New-SaMissileLayer $script:dlFrame
if($layer.Children.Count -ne 1 -or $layer.Children[0].Children[1].Text -ne '5V28'){throw 'SA Export missile position/type not displayed'}
$script:exportMissileFrame.missiles=@()
if((Get-ActiveMissileFeed).Source -ne 'MISSION'){throw 'Empty Export suppressed mission coordinates'}
Draw-JesterMissiles
if(-not $script:jesterMissileCache.ContainsKey('mission1') -or $script:jesterMissileCache.ContainsKey('export1')){throw 'Source change retained duplicate missile'}
$rwr=Get-MissionRwrFrame
if($rwr.contacts[0].native_code -ne '5' -or $rwr.contacts[0].hour -ne 12 -or $rwr.contacts[0].activity -ne 'lock'){throw 'Mission SA-5 receiver decode failed'}
$script:missionLast=[datetime]::UtcNow.AddSeconds(-3)
if((Get-ActiveMissileFeed).Source -ne 'JESTER'){throw 'Stale mission did not fall back'}
$script:exportMissileFrame.missiles=@([pscustomobject]@{id='export1';identity='HOSTILE';p=@{x=1000;y=100;z=100}})
$script:modernRwrEnabled=$false
if((Get-ActiveMissileFeed).Source -ne 'JESTER'){throw 'Original mode did not retain Jester'}
if($null -ne (ConvertFrom-WorldMissileLine 'F4EXPORT_MISSILES_V1|{"state":"LIVE","missiles":[{"id":"bad","identity":"HOSTILE","p":{"x":1}}]}')){throw 'Invalid world missile accepted'}
$script:exportMissileFrame=$null;$script:missionFrame=$null;$script:jesterMissileCache=@{}
Write-Output 'PASS: Export > mission > Jester missile priority, empty/stale fallback, world projection, source isolation, mission SA-5 and original mode (synthetic fixtures)'
