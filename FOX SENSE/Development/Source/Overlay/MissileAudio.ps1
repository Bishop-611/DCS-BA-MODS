$script:rwrWarningEnabled=$true
$script:missileAudioSeen=@{}
$script:missileAudioQueue=New-Object 'System.Collections.Generic.Queue[string]'
$script:missileAudioLastPacket=[datetime]::MinValue
$script:missileAudioLastSequence=$null
$script:missileAudioNext=[datetime]::MinValue
$script:missileTonePlayer=$null
$script:missileToneDuration=0.849
$script:missileAudioSource='JESTER'
function Test-MissileAudioThreat($Entry,[string]$Source){
    if( $Entry.own_launch -eq $true){return $false}
    if($Source -eq 'MISSION'){return $Entry.inbound -eq $true}
    if($Entry.identity -notin @('HOSTILE','FRIENDLY')){return $false}
    if($script:incomingSource -ne $Source){return $false}
    $sample=$script:incomingSamples[[string]$Entry.id]
    return $null -ne $sample -and $sample.Incoming -eq $true
}
function Update-MissileDiscoveryAudio {
    $now=[datetime]::UtcNow
    $feed=Get-ActiveMissileFeed
    $f=$feed.Packet
    if($script:missileAudioSource -ne $feed.Source){$script:missileAudioSource=$feed.Source;$script:missileAudioLastSequence=$null;$script:missileAudioLastPacket=[datetime]::MinValue;$script:missileAudioQueue.Clear()}
    if($null -ne $f -and ($feed.Last -ne $script:missileAudioLastPacket -or ($null -ne $f.sequence -and $f.sequence -ne $script:missileAudioLastSequence)) -and ($now-$feed.Last).TotalSeconds -le 1.5){
        $script:missileAudioLastPacket=$feed.Last
        if($null -ne $f.sequence){
            $sequence=[long]$f.sequence
            if($null -ne $script:missileAudioLastSequence -and $sequence -lt $script:missileAudioLastSequence){
                $script:missileAudioSeen=@{};$script:missileAudioQueue.Clear()
            }
            $script:missileAudioLastSequence=$sequence
        }
        if($f.state -eq 'AWARENESS'){
            foreach($entry in @($f.missiles)){
                $id=[string]$entry.id
                if(-not (Test-MissileAudioThreat $entry $feed.Source)){continue}
                if(-not (Test-AlertMissileRange $entry $f)){continue}
                if(-not $id -or [double]$entry.age_s+($now-$feed.Last).TotalSeconds -gt 1.5){continue}
                if(-not $script:missileAudioSeen.ContainsKey($id)){
                    $script:missileAudioSeen[$id]=$true
                    # Muted discoveries stay seen; enabling audio does not replay old contacts.
                    if($audio.IsChecked -and $script:rwrWarningEnabled){$script:missileAudioQueue.Enqueue($id)}
                }
            }
        }
    }
    # Queued sounds must still belong to a currently fresh, in-range inbound contact.
    $eligible=@{}
    if($null -ne $f -and $f.state -eq 'AWARENESS' -and ($now-$feed.Last).TotalSeconds -le 1.5){
        foreach($entry in @($f.missiles)){
            if([double]$entry.age_s+($now-$feed.Last).TotalSeconds -le 1.5 -and (Test-AlertMissileRange $entry $f) -and (Test-MissileAudioThreat $entry $feed.Source)){$eligible[[string]$entry.id]=$true}
        }
    }
    $pending=$script:missileAudioQueue.Count
    for($index=0;$index -lt $pending;$index++){$queued=$script:missileAudioQueue.Dequeue();if($eligible.ContainsKey($queued)){$script:missileAudioQueue.Enqueue($queued)}}
    if(-not $audio.IsChecked -or -not $script:rwrWarningEnabled){$script:missileAudioQueue.Clear();return}
    if($script:incomingThreatActive -and ($null -eq $incomingAudioCheckbox -or $incomingAudioCheckbox.IsChecked)){$script:missileAudioQueue.Clear();return}
    if($script:radarLockActive -and $script:rwrWarningEnabled){$script:missileAudioQueue.Clear();return}
    if($SelfTest -or $RenderPreview -or $script:missileAudioQueue.Count -eq 0 -or $now -lt $script:missileAudioNext){return}
    if($null -eq $script:missileTonePlayer){
        $tonePath=Join-Path $PSScriptRoot 'Audio\ALR67_Tone_3.wav'
        $script:missileTonePlayer=[Windows.Media.MediaPlayer]::new();$script:missileTonePlayer.Volume=$script:audioVolume;$script:missileTonePlayer.Open([uri]$tonePath)

    }
    $script:missileTonePlayer.Position=[timespan]::Zero;$script:missileTonePlayer.Play()
    [void]$script:missileAudioQueue.Dequeue()
    $script:missileAudioNext=$now.AddSeconds($script:missileToneDuration+0.05)
}
