Play-MenuAudio 'Open'
if($script:menuAudioLast -ne 'Open'){throw 'Menu opening clip selection failed'}
$before=$script:menuAudioRequests
Play-MenuAudio 'Close'
if($script:menuAudioLast -ne 'Close' -or $script:menuAudioRequests -ne $before+1){throw 'Menu closing clip selection failed'}
if($null -ne $script:menuAudioPlayer){throw 'Self-test must not play menu audio'}
Stop-MenuAudio
Play-MenuAudio 'OverlayHide'
if($script:menuAudioLast -ne 'OverlayHide'){throw 'Overlay hide clip file missing'}
Play-MenuAudio 'OverlayShow'
if($script:menuAudioLast -ne 'OverlayShow'){throw 'Overlay restore clip file missing'}
Write-Output 'PASS: menu open/close clip selection, files embedded and self-test remains silent'
