$c=Load-Xaml 'Controls.xaml';$audio=$c.FindName('Audio');$incomingAudioCheckbox=$c.FindName('IncomingAudio')
$script:modernRwrEnabled=$true;$script:exportMissileFrame=$null;$script:jesterMissileFrame=$null
$script:incomingSamples=@{};$script:incomingSource='';$script:incomingPacketKey='';$script:incomingNextTone=[datetime]::MinValue;$script:incomingPlaybackRequests=0
function Set-TestInbound([datetime]$Now,[double]$Time,[double]$X,[bool]$Inbound,[string]$Identity='HOSTILE'){
    $script:exportMissileFrame=$null
    $script:missionFrame=[pscustomobject]@{state='SIM_RECEIVER';sequence=[int]($Time*10);sample_time=$Time;ownship=@{x=0;y=0;z=0};missiles=@([pscustomobject]@{id='incoming1';identity=$Identity;inbound=$Inbound;p=@{x=$X;y=0;z=0}})}
    $script:missionLast=$Now
}
$start=[datetime]::UtcNow
Set-TestInbound $start 0 10000 $true;Update-IncomingMissileAudio $start
Set-TestInbound $start.AddMilliseconds(500) 0.5 9750 $true;Update-IncomingMissileAudio $start.AddMilliseconds(500)
if($script:incomingPlaybackRequests -ne 1){throw 'Incoming tone played before one second'}
Set-TestInbound $start.AddSeconds(1) 1 9500 $true;Update-IncomingMissileAudio $start.AddSeconds(1);Complete-WarningClip 4
Set-TestInbound $start.AddSeconds(2) 2 9000 $true;Update-IncomingMissileAudio $start.AddSeconds(2);Complete-WarningClip 4
if($script:incomingPlaybackRequests -ne 3){throw 'Incoming tone did not restart on media completion'}
$script:missionFrame.missiles=@();Update-IncomingMissileAudio $start.AddMilliseconds(2100)
if($script:incomingThreatActive){throw 'Incoming warning survived removed threat'}
Set-TestInbound $start.AddSeconds(3) 3 8500 $true;Update-IncomingMissileAudio $start.AddSeconds(3)
$before=$script:incomingPlaybackRequests;$audio.IsChecked=$false
Update-IncomingMissileAudio $start.AddSeconds(4)
if($script:incomingPlaybackRequests -ne $before){throw 'Muted incoming tone played'}
$audio.IsChecked=$true;Update-IncomingMissileAudio $start.AddSeconds(6)
if($script:incomingThreatActive){throw 'Stale missile continued warning'}
$script:incomingSamples=@{};$script:incomingPacketKey=''
foreach($step in 0..2){$time=10+0.2*$step;$now=$start.AddSeconds($time);Set-TestInbound $now $time (10000-200*$step) $false;$script:exportMissileFrame=$script:missionFrame.PSObject.Copy();$script:exportMissileFrame.state='LIVE';$script:exportMissileLast=$now;Update-IncomingMissileAudio $now}
if(-not $script:incomingThreatActive){throw 'Persistent closing trajectory not detected'}
Set-TestInbound $start.AddSeconds(10.6) 10.6 11000 $false;Update-IncomingMissileAudio $start.AddSeconds(10.6)
if($script:incomingThreatActive){throw 'Receding missile continued warning'}
$script:incomingSamples=@{};$script:incomingPacketKey=''
foreach($step in 0..2){$time=20+0.2*$step;$now=$start.AddSeconds($time);Set-TestInbound $now $time (10000-200*$step) $false 'FRIENDLY';Update-IncomingMissileAudio $now}
if($script:incomingThreatActive){throw 'Friendly positional track caused inferred warning'}
$tone=[System.Media.SoundPlayer]::new((Join-Path $PSScriptRoot 'Audio\ALR67_Tone_4.wav'));$tone.Load();$tone.Dispose()
foreach($step in 0..2){
    $time=25+0.2*$step;$now=$start.AddSeconds($time)
    Set-TestInbound $now $time (10000-200*$step) $false;Update-IncomingMissileAudio $now
}
if($script:incomingThreatActive){throw 'Mission missile aimed elsewhere was promoted by approach inference'}
Set-TestInbound $start.AddSeconds(26) 26 5000 $true 'UNKNOWN'
$script:missionFrame.missiles[0]|Add-Member -NotePropertyName own_launch -NotePropertyValue $true
Update-IncomingMissileAudio $start.AddSeconds(26)
if($script:incomingThreatActive){throw 'Explicit own-launch flag caused incoming alarm'}
Set-LaunchWarningRange 20;Set-AlertRange 60
Set-TestInbound $start.AddSeconds(30) 30 (30*1852) $true;Update-IncomingMissileAudio $start.AddSeconds(30)
if($script:incomingThreatActive){throw 'Tone 4 used RWR range instead of Launch warning range'}
Set-LaunchWarningRange 40;Set-AlertRange 20
Set-TestInbound $start.AddSeconds(31) 31 (30*1852) $true;Update-IncomingMissileAudio $start.AddSeconds(31)
if(-not $script:incomingThreatActive){throw 'Tone 4 did not expand with Launch warning range'}
Set-LaunchWarningRange 20;Update-IncomingMissileAudio $start.AddSeconds(31)
if($script:incomingThreatActive){throw 'Tone 4 did not stop immediately on Launch warning range reduction'}
Set-LaunchWarningRange 60
Set-TestInbound $start.AddSeconds(32) 32 (60*1852) $true;Update-IncomingMissileAudio $start.AddSeconds(32)
if(-not $script:incomingThreatActive){throw 'Tone 4 excluded SA boundary'}
Set-TestInbound $start.AddSeconds(33) 33 (60*1852+1) $true;Update-IncomingMissileAudio $start.AddSeconds(33)
if($script:incomingThreatActive){throw 'Tone 4 included outside-SA missile'}
Set-LaunchWarningRange 20
Write-Output 'PASS: Launch warning independent range 20/40/60 NM, ignores RWR symbol range, immediate shrink stop and inclusive boundary'
$script:incomingSamples=@{};$script:incomingThreatActive=$false;$script:missionFrame=$null;$script:modernRwrEnabled=$false
Write-Output 'PASS: Tone 4 loads; media-completion loop, stop on removal/stale/mute, explicit mission target and persistent approach/receding/friendly filtering; no sound played in self-test'
