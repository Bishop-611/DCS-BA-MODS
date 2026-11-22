$script:radarLockActive=$false;$script:radarContactsPresent=$false;$script:radarLockToneRequests=0;$script:radarAudioDiagnostic=$null

function Get-RadarAudioEvidence {
    $selected=Get-ActiveRwrFrame;$frames=@($selected)
    if($selected.source -eq 'MISSION'){$frames=@()}
    if($selected.state -ne 'TEST' -and $script:modernRwrEnabled){
        if($null -ne $script:rwrContacts -and $script:rwrContacts.state -eq 'LIVE' -and ([datetime]::UtcNow-$script:rwrContactsLast).TotalSeconds -le 2){$frames+=,(Limit-RwrFrame ([pscustomobject]@{state='LIVE';source='JESTER';contacts=$script:rwrContacts.contacts}))}
    }
    $present=$false;$locked=$false;$sources=@()
    foreach($frame in $frames){
        if($frame.state -ne 'LIVE'){continue}
        if(@($frame.contacts).Count -gt 0){$present=$true}
        $activities=@($frame.contacts|ForEach-Object {$_.activity}|Select-Object -Unique)
        $sources+=[pscustomobject]@{source=$frame.source;activities=$activities}
        if(@($frame.contacts|Where-Object {$_.activity -in @('lock','track','locked')}).Count -gt 0){$locked=$true}
    }
    return [pscustomobject]@{present=$present;locked=$locked;selected=$selected.source;state=$selected.state;sources=$sources}
}
function Update-RadarLockAudio([datetime]$Now=[datetime]::UtcNow){
    $evidence=Get-RadarAudioEvidence;$script:radarAudioDiagnostic=$evidence
    $first=$evidence.present -and -not $script:radarContactsPresent
    $script:radarContactsPresent=$evidence.present;$script:radarLockActive=$evidence.locked
    $priority=$script:incomingThreatActive -and ($null -eq $incomingAudioCheckbox -or $incomingAudioCheckbox.IsChecked)
    if(-not $audio.IsChecked -or -not $script:rwrWarningEnabled -or $priority){Stop-RadarToneLoop;return}
    if($evidence.locked){
        if($script:radarToneLoop){return}
        Initialize-WarningPlayer 3;$script:radarToneLoop=$true;$script:radarLockToneRequests++
        if(-not $SelfTest -and -not $RenderPreview){$script:missileTonePlayer.Position=[timespan]::Zero;$script:missileTonePlayer.Play()}
        return
    }
    Stop-RadarToneLoop
    if(-not $first -or $Now -lt $script:missileAudioNext){return}
    Initialize-WarningPlayer 3;$script:radarLockToneRequests++
    if(-not $SelfTest -and -not $RenderPreview){$script:missileTonePlayer.Position=[timespan]::Zero;$script:missileTonePlayer.Play()}
    $script:missileAudioNext=$Now.AddSeconds($script:missileToneDuration+0.05)
}
