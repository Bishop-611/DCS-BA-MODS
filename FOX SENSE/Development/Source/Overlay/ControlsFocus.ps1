if(-not ('FoxControlsFocus' -as [type])){
    Add-Type -Path (Join-Path $PSScriptRoot 'ControlsFocus.cs') -ReferencedAssemblies @(
        'System.dll', [Windows.Interop.HwndSource].Assembly.Location, [Windows.Threading.Dispatcher].Assembly.Location)
}
$script:controlsFocus=$null
function Toggle-ControlsPanel {
    if($controls.IsVisible -and $controls.WindowState -ne 'Minimized'){Hide-ControlsPanel;return}
    $controls.WindowState='Normal'
    $controls.ShowActivated=$false
    Place-ControlsNearBubble
    $controls.Show()
    Play-MenuAudio 'Open'
}
function Hide-ControlsPanel([switch]$Silent) {
    $wasVisible=$controls.IsVisible -and $controls.WindowState -ne 'Minimized'
    if($null -ne $script:menuBubble -or ($null -ne $script:controlsFocus -and $script:controlsFocus.HotkeyRegistered)){$controls.Hide()}
    else{$controls.WindowState='Minimized'}
    if($wasVisible -and -not $Silent){Play-MenuAudio 'Close'}
}
function Initialize-ControlsFocus {
    $handle=[Windows.Interop.WindowInteropHelper]::new($controls).Handle
    $script:controlsFocus=[FoxControlsFocus]::new($handle,$true)
    $script:controlsFocus.add_ToggleRequested({Toggle-ControlsPanel})
}
