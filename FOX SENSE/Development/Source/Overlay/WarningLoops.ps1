$script:radarToneLoop=$false;$script:incomingToneLoop=$false
$script:tone3HookedPlayer=$null;$script:tone4HookedPlayer=$null
function Write-WarningAudioFailure([int]$Kind,$ErrorEvent){
    if($Kind -eq 4){$script:incomingToneLoop=$false}else{$script:radarToneLoop=$false}
    $message='Tone '+$Kind+': '+[string]$ErrorEvent.ErrorException
    [IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot) 'warning-audio-error.txt'),$message)
}
function Complete-WarningClip([int]$Kind){
    $loop=if($Kind -eq 4){$script:incomingToneLoop}else{$script:radarToneLoop}
    if(-not $loop){return}
    if($Kind -eq 4){$script:incomingPlaybackRequests++;$player=$script:incomingTonePlayer}
    else{$script:radarLockToneRequests++;$player=$script:missileTonePlayer}
    if(-not $SelfTest -and -not $RenderPreview -and $player){$player.Position=[timespan]::Zero;$player.Play()}
}
function Initialize-WarningPlayer([int]$Kind){
    if($SelfTest -or $RenderPreview){return}
    if($Kind -eq 4){
        if($null -eq $script:incomingTonePlayer){$script:incomingTonePlayer=[Windows.Media.MediaPlayer]::new();$script:incomingTonePlayer.Volume=$script:audioVolume;$script:incomingTonePlayer.Open([uri](Join-Path $PSScriptRoot 'Audio\ALR67_Tone_4.wav'))}
        if($script:tone4HookedPlayer -ne $script:incomingTonePlayer){$script:incomingTonePlayer.Add_MediaEnded({Complete-WarningClip 4});$script:incomingTonePlayer.Add_MediaFailed({Write-WarningAudioFailure 4 $args[1]});$script:tone4HookedPlayer=$script:incomingTonePlayer}
    }else{
        if($null -eq $script:missileTonePlayer){$script:missileTonePlayer=[Windows.Media.MediaPlayer]::new();$script:missileTonePlayer.Volume=$script:audioVolume;$script:missileTonePlayer.Open([uri](Join-Path $PSScriptRoot 'Audio\ALR67_Tone_3.wav'))}
        if($script:tone3HookedPlayer -ne $script:missileTonePlayer){$script:missileTonePlayer.Add_MediaEnded({Complete-WarningClip 3});$script:missileTonePlayer.Add_MediaFailed({Write-WarningAudioFailure 3 $args[1]});$script:tone3HookedPlayer=$script:missileTonePlayer}
    }
}
function Stop-RadarToneLoop {
    if($script:radarToneLoop -and $script:missileTonePlayer){$script:missileTonePlayer.Stop()}
    $script:radarToneLoop=$false
}
function Stop-IncomingToneLoop {
    $script:incomingToneLoop=$false
    if($script:incomingTonePlayer){$script:incomingTonePlayer.Stop()}
}
