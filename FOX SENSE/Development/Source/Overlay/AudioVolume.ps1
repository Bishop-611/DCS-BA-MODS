$script:audioVolume=1.0;$script:receiverAudioPlayer=$null
function Set-HudAudioVolume([double]$Volume){
    if([double]::IsNaN($Volume) -or [double]::IsInfinity($Volume)){return}
    $script:audioVolume=[Math]::Max(0.0,[Math]::Min(1.0,$Volume))
    foreach($player in @($script:menuAudioPlayer,$script:incomingTonePlayer,$script:missileTonePlayer,$script:receiverAudioPlayer)){
        if($null -ne $player){$player.Volume=$script:audioVolume}
    }
}
function Play-ReceiverAudio([string]$File){
    if($SelfTest -or $RenderPreview){return}
    if($null -eq $script:receiverAudioPlayer){$script:receiverAudioPlayer=[Windows.Media.MediaPlayer]::new()}
    $script:receiverAudioPlayer.Stop();$script:receiverAudioPlayer.Volume=$script:audioVolume
    $script:receiverAudioPlayer.Open([uri](Join-Path $PSScriptRoot ('Audio\'+$File)));$script:receiverAudioPlayer.Play()
}
