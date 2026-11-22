$script:overlaysHidden=$false;$script:syncOverlaySwitch=$false
function Set-GameOverlaysVisible([bool]$Visible){
    $changed=(-not $script:overlaysHidden) -ne $Visible
    $script:overlaysHidden=-not $Visible
    $hud.Visibility=if($Visible){'Visible'}else{'Hidden'}
    if($null -ne $controls){
        $script:syncOverlaySwitch=$true
        try{$controls.FindName('AllOverlaysToggle').IsChecked=$Visible}finally{$script:syncOverlaySwitch=$false}
        $controls.FindName('AllOverlaysLabel').Text=if($Visible){'HUD: ON'}else{'HUD: OFF'}
    }
    if($changed){Play-MenuAudio $(if($Visible){'OverlayShow'}else{'OverlayHide'})}
}
function Toggle-GameOverlays {Set-GameOverlaysVisible $script:overlaysHidden}
