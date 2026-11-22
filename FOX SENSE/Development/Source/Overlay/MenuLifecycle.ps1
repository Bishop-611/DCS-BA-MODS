$script:exitRequested=$false
function Handle-MenuClosing($EventArgs){
    if($script:exitRequested -or [Environment]::HasShutdownStarted -or ($null -ne $script:controlsFocus -and $script:controlsFocus.SystemEnding)){return}
    $EventArgs.Cancel=$true
    Hide-ControlsPanel
}
function Exit-FoxApplication {
    $script:exitRequested=$true
    $controls.Close()
}
