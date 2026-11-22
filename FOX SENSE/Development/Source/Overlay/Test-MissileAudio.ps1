$audio=$testControls.FindName('Audio');$audio.IsChecked=$true
$script:missileAudioSeen=@{};$script:missileAudioQueue.Clear();$script:missileAudioLastPacket=[datetime]::MinValue;$script:missileAudioLastSequence=$null
$script:modernRwrEnabled=$false;$script:incomingThreatActive=$false;$script:incomingSource='JESTER';$script:incomingSamples=@{}
function Test-AudioPacket([long]$Sequence,$Entries){
 $script:jesterMissileFrame=[pscustomobject]@{state='AWARENESS';sequence=$Sequence;missiles=@($Entries)}
 $script:jesterMissileLast=[datetime]::UtcNow;Update-MissileDiscoveryAudio
}
$own=[pscustomobject]@{id='own';age_s=0;identity='FRIENDLY';own_launch=$true}
$unknown=[pscustomobject]@{id='unknown';age_s=0;identity='UNKNOWN'}
$enemy=[pscustomobject]@{id='enemy';age_s=0;identity='HOSTILE'}
Test-AudioPacket 10 @($own,$unknown,$enemy)
if($script:missileAudioQueue.Count -ne 0){throw 'Tone 3 queued on generic discovery'}
$script:incomingSamples=@{own=@{Incoming=$true};unknown=@{Incoming=$true};enemy=@{Incoming=$true}}
Test-AudioPacket 11 @($own,$unknown,$enemy)
if($script:missileAudioQueue.Count -ne 1 -or $script:missileAudioQueue.Peek() -ne 'enemy'){throw 'Tone 3 did not select inbound enemy only'}
Test-AudioPacket 12 @($enemy)
if($script:missileAudioQueue.Count -ne 1){throw 'Repeated contact replayed Tone 3'}
Test-AudioPacket 13 @()
if($script:missileAudioQueue.Count -ne 0){throw 'Removed missile remained queued'}
Test-AudioPacket 14 @($enemy)
if($script:missileAudioQueue.Count -ne 0){throw 'Reacquired missile replayed Tone 3'}
Test-AudioPacket 1 @($enemy)
if($script:missileAudioQueue.Count -ne 1){throw 'Mission reset failed'}
$script:incomingSamples.enemy.Incoming=$false;Test-AudioPacket 2 @($enemy)
if($script:missileAudioQueue.Count -ne 0){throw 'Receding threat remained queued'}
if(Test-MissileAudioThreat @{id='x';identity='HOSTILE';inbound=$false} 'MISSION'){throw 'Mission non-inbound allowed'}
if(Test-MissileAudioThreat @{id='x';identity='UNKNOWN';inbound=$true;own_launch=$true} 'MISSION'){throw 'Own launch allowed'}
if(-not (Test-MissileAudioThreat @{id='x';identity='HOSTILE';inbound=$true} 'MISSION')){throw 'Inbound threat rejected'}
$audio.IsChecked=$false;Test-AudioPacket 3 @($enemy)
if($script:missileAudioQueue.Count -ne 0){throw 'Muted queue not cleared'}
$audio.IsChecked=$true
$friend=[pscustomobject]@{id='friend';age_s=0;identity='FRIENDLY'}
$script:incomingSamples=@{friend=@{Incoming=$true}}
Test-AudioPacket 4 @($friend)
if($script:missileAudioQueue.Count -ne 1 -or $script:missileAudioQueue.Peek() -ne 'friend'){throw 'Friendly inbound excluded from Tone 3'}
if(-not (Test-MissileAudioThreat @{identity='FRIENDLY';inbound=$true} 'MISSION')){throw 'Explicit friendly inbound rejected'}
if(Test-MissileAudioThreat @{identity='FRIENDLY';inbound=$false} 'MISSION'){throw 'Friendly outgoing missile allowed'}
$script:incomingSamples=@{};$script:missileAudioQueue.Clear()
$tone=[System.Media.SoundPlayer]::new((Join-Path $PSScriptRoot 'Audio\ALR67_Tone_3.wav'));$tone.Load();$tone.Dispose()
Write-Output 'PASS: Tone 3 rejects own/unconfirmed/non-inbound discoveries; accepts friendly inbound, queues inbound once, clears removed/receding threats, resets per mission; no sound played'
