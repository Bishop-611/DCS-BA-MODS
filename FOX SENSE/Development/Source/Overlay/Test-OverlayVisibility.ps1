$controls=Load-Xaml 'Controls.xaml'
$controls.FindName('DatalinkEnabled').IsChecked=$true
$controls.FindName('DatalinkOverlayEnabled').IsChecked=$true
$controls.FindName('DatalinkOverlayScale').Value=1.4
$controls.FindName('DatalinkOverlayX').Value=300
$controls.FindName('Audio').IsChecked=$true
$realControls=$controls
$controls=[pscustomobject]@{IsVisible=$true;WindowState='Normal';Window=$realControls;HiddenCalls=0}
$controls|Add-Member ScriptMethod FindName {param($name) $this.Window.FindName($name)}
$controls|Add-Member ScriptMethod Hide {$this.HiddenCalls++;$this.IsVisible=$false}
Set-GameOverlaysVisible $false
if(-not $controls.IsVisible -or $controls.WindowState -ne 'Normal' -or $controls.HiddenCalls -ne 0){throw 'HUD switch closed or minimized open settings'}
Set-GameOverlaysVisible $true
$controls=$realControls
Set-GameOverlaysVisible $false
if($script:menuAudioLast -ne 'OverlayHide'){throw 'Overlay hide did not select okay clip'}
$requests=$script:menuAudioRequests;Set-GameOverlaysVisible $false
if($script:menuAudioRequests -ne $requests){throw 'Unchanged visibility replayed UI audio'}
if($hud.Visibility -ne 'Hidden' -or $controls.FindName('AllOverlaysToggle').IsChecked -ne $false){throw 'Master switch did not hide complete HUD'}
if(-not $controls.FindName('Audio').IsChecked -or -not $controls.FindName('DatalinkOverlayEnabled').IsChecked -or $controls.FindName('DatalinkOverlayScale').Value -ne 1.4 -or $controls.FindName('DatalinkOverlayX').Value -ne 300){throw 'Hide changed saved overlay or audio settings'}
Toggle-GameOverlays
if($script:menuAudioLast -ne 'OverlayShow'){throw 'Overlay restore did not select un clip'}
if($hud.Visibility -ne 'Visible' -or $controls.FindName('AllOverlaysToggle').IsChecked -ne $true){throw 'Hotkey restore did not sync slider'}

foreach($name in @('OverlayHotkeyLabel','BindOverlayHotkey','OverlayModifiers','OverlayKey')){
 if($controls.FindName($name)){throw 'Removed HUD shortcut widget remains'}
}
if([FoxControlsFocus].GetMethod('ConfigureOverlayKey') -or [FoxControlsFocus].GetMethod('PollOverlayHotkey') -or [FoxControlsFocus].GetMethod('BeginOverlayKeyCapture')){throw 'Removed HUD keyboard handling remains'}
$path=Join-Path $env:TEMP ('fox-no-shortcut-'+[guid]::NewGuid().ToString('N')+'.json')
try{
 Save-HudSettings $controls $path
 $v=([IO.File]::ReadAllText($path)|ConvertFrom-Json).values
 if($null -ne $v.OverlayKey -or $null -ne $v.OverlayModifiers){throw 'HUD shortcut still saved'}
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
Set-GameOverlaysVisible $true;$controls=$null
Write-Output 'PASS: HUD switch and show/hide sounds retained; HUD shortcut widgets, key handling and saved binding removed'
