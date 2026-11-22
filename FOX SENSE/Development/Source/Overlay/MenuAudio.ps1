$script:menuAudioPlayer=$null
$script:menuAudioLast=''
$script:menuAudioRequests=0
function Play-MenuAudio([ValidateSet('Open','Close','OverlayHide','OverlayShow')][string]$Action){
    $path=Join-Path $PSScriptRoot ('Audio\Menu'+$Action+'.mp3')
    if(-not [IO.File]::Exists($path)){return}
    $script:menuAudioLast=$Action;$script:menuAudioRequests++
    if($SelfTest -or $RenderPreview){return}
    try{
        if($script:menuAudioPlayer){$script:menuAudioPlayer.Stop();$script:menuAudioPlayer.Close()}
        $script:menuAudioPlayer=[Windows.Media.MediaPlayer]::new()
        $script:menuAudioPlayer.Volume=$script:audioVolume
        $script:menuAudioPlayer.Open([uri]$path)
        $script:menuAudioPlayer.Play()
    }catch{
        [IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot) 'menu-audio-error.txt'),($_|Out-String))
    }
}
function Stop-MenuAudio {
    if($script:menuAudioPlayer){$script:menuAudioPlayer.Stop();$script:menuAudioPlayer.Close();$script:menuAudioPlayer=$null}
}
