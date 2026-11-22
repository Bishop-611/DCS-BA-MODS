$controls=Load-Xaml 'Controls.xaml';$audio=$controls.FindName('Audio');$audio.IsChecked=$true;$incomingAudioCheckbox=$controls.FindName('IncomingAudio')
$script:modernRwrEnabled=$true;$script:missionFrame=$null;$script:rwrContacts=$null;$script:receiverEvent=$null
$script:nativeRwr=[pscustomobject]@{state='LIVE';contacts=@([pscustomobject]@{hour=12;activity='search'})};$script:nativeRwrLast=[datetime]::UtcNow
$script:radarToneLoop=$false;$script:incomingToneLoop=$false;$script:radarLockActive=$false;$script:radarContactsPresent=$false;$script:radarLockToneRequests=0;$script:missileAudioNext=[datetime]::MinValue;$script:incomingThreatActive=$false;$script:rwrWarningEnabled=$true
$start=[datetime]::UtcNow
Update-RadarLockAudio $start;Update-RadarLockAudio $start.AddMilliseconds(100)
if($script:radarLockToneRequests -ne 1 -or $script:radarToneLoop){throw 'First contact must play once without looping'}
$script:nativeRwr.contacts[0].activity='lock';Update-RadarLockAudio $start.AddMilliseconds(200)
if(-not $script:radarToneLoop -or $script:radarLockToneRequests -ne 2){throw 'Lock did not begin continuous loop'}
foreach($step in 1..10){Update-RadarLockAudio $start.AddMilliseconds(200+$step*33)}
if($script:radarLockToneRequests -ne 2){throw 'HUD ticks restarted playing audio'}
Complete-WarningClip 3;Complete-WarningClip 3
if($script:radarLockToneRequests -ne 4){throw 'Tone 3 did not loop immediately on clip completion'}
$script:nativeRwr.contacts[0].activity='search';Update-RadarLockAudio $start.AddSeconds(1)
Complete-WarningClip 3
if($script:radarToneLoop -or $script:radarLockToneRequests -ne 4){throw 'Unlock did not stop media looping'}
# A native search contact must not mask a separate fresh Jester lock.
$script:rwrContacts=[pscustomobject]@{state='LIVE';contacts=@([pscustomobject]@{hour=3;activity='lock'})};$script:rwrContactsLast=[datetime]::UtcNow
Update-RadarLockAudio $start.AddSeconds(2)
if(-not $script:radarToneLoop -or $script:radarAudioDiagnostic.selected -ne 'NATIVE'){throw 'Fresh secondary-source lock was masked by selected search source'}
$script:incomingThreatActive=$true;Update-RadarLockAudio $start.AddSeconds(3)
if($script:radarToneLoop){throw 'Lock loop interrupted Launch warning'}
$script:incomingThreatActive=$false;Update-RadarLockAudio $start.AddSeconds(4)
if(-not $script:radarToneLoop){throw 'Lock loop did not resume after Launch warning'}
$script:rwrContactsLast=[datetime]::UtcNow.AddSeconds(-3);$script:nativeRwrLast=[datetime]::UtcNow.AddSeconds(-3)
Update-RadarLockAudio $start.AddSeconds(5)
if($script:radarToneLoop){throw 'Stale lock loop persisted'}
$script:nativeRwr=[pscustomobject]@{state='UNAVAILABLE';contacts=@()};$script:nativeRwrLast=[datetime]::UtcNow
$script:rwrContacts=[pscustomobject]@{state='LIVE';contacts=@([pscustomobject]@{hour=12;activity='none'})};$script:rwrContactsLast=[datetime]::UtcNow
Update-RadarLockAudio $start.AddSeconds(6)
if($script:radarToneLoop -or $script:radarAudioDiagnostic.locked){throw 'Missing lock data was fabricated from contact presence'}
$script:rwrContacts.contacts[0].activity='lock';$script:rwrWarningEnabled=$false;Update-RadarLockAudio $start.AddSeconds(7)
if($script:radarToneLoop){throw 'Disabled RWR warning looped'}
$script:rwrWarningEnabled=$true;$script:nativeRwr=$null;$script:rwrContacts=$null;$script:radarLockActive=$false;$script:radarContactsPresent=$false;$script:missileAudioNext=[datetime]::MinValue;$controls=$null
Stop-RadarToneLoop;Stop-IncomingToneLoop
Write-Output 'PASS: first contact once, clip-completion Tone 3 loop without timer restarts, secondary lock source, unlock/stale/switch stop, Launch priority/resume and missing-lock data not fabricated; no sound played'
