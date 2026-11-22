$real=Load-Xaml 'Controls.xaml'
if($null -eq $real.FindName('ExitApplication')){throw 'Explicit exit button missing'}
$controls=[pscustomobject]@{IsVisible=$true;WindowState='Normal';Window=$real;HiddenCalls=0;CloseCalls=0}
$controls|Add-Member ScriptMethod FindName {param($name) $this.Window.FindName($name)}
$controls|Add-Member ScriptMethod Hide {$this.HiddenCalls++;$this.IsVisible=$false}
$controls|Add-Member ScriptMethod Close {$this.CloseCalls++}
$priorBubble=$script:menuBubble;$script:menuBubble=[pscustomobject]@{present=$true}
$script:exitRequested=$false
$hudBefore=$hud.Visibility
try{
    $event=[ComponentModel.CancelEventArgs]::new();Handle-MenuClosing $event
    if(-not $event.Cancel -or $controls.HiddenCalls -ne 1 -or $controls.CloseCalls -ne 0 -or $hud.Visibility -ne $hudBefore){throw 'X must collapse only settings without exiting HUD'}
    Exit-FoxApplication
    if(-not $script:exitRequested -or $controls.CloseCalls -ne 1){throw 'Exit button did not request application shutdown'}
    $event=[ComponentModel.CancelEventArgs]::new();Handle-MenuClosing $event
    if($event.Cancel){throw 'Explicit application exit was cancelled'}
}finally{$script:menuBubble=$priorBubble;$controls=$null;$script:exitRequested=$false}
Write-Output 'PASS: X cancels window close and hides menu only; explicit Exit application permits shutdown; no visible window created'
