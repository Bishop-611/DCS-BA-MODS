Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FoxFocusTestNative {
 [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int index);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,int message,IntPtr wParam,IntPtr lParam);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
'@
$probe=Load-Xaml 'Controls.xaml'
if($probe.ShowActivated -or $probe.Focusable){throw 'Settings would activate when shown'}
foreach($name in @('Audio','ModernRwrEnabled','DatalinkOverlayScale','HideControls','Range20','Range40','Range60')){
    if($probe.FindName($name).Focusable){throw "Settings widget may take keyboard focus: $name"}
}
if($probe.FindName('DatalinkRange').Visibility -ne 'Collapsed'){throw 'Popup range selector must be replaced by mouse buttons'}
$foreground=[FoxFocusTestNative]::GetForegroundWindow()
$handle=[Windows.Interop.WindowInteropHelper]::new($probe).EnsureHandle()
$focus=[FoxControlsFocus]::new($handle,$false)
try{
    $style=[FoxFocusTestNative]::GetWindowLong($handle,-20)
    if(($style -band 0x08000000) -eq 0 -or ($style -band 0x20) -ne 0){throw 'Settings must be no-activate but mouse-interactive'}
    $result=[FoxFocusTestNative]::SendMessage($handle,0x0021,[IntPtr]::Zero,[IntPtr]::Zero)
    if($result.ToInt32() -ne 3){throw 'WM_MOUSEACTIVATE must preserve the click without activation'}
    if([FoxFocusTestNative]::GetForegroundWindow() -ne $foreground){throw 'No-activate test changed foreground window'}
    $script:testToggleCount=0;$focus.add_ToggleRequested({$script:testToggleCount++})
    [void][FoxFocusTestNative]::SendMessage($handle,0x0312,[IntPtr]::new([FoxControlsFocus]::HotkeyId),[IntPtr]::Zero)
    if($script:testToggleCount -ne 1){throw 'Settings hotkey dispatch failed'}
}finally{$focus.Dispose();$focus.Dispose();$probe.Close()}
$bubble=Load-Xaml 'FloatingMenu.xaml'
if($bubble.ShowActivated -or $bubble.ShowInTaskbar -or $bubble.Focusable){throw 'Floating menu must not take focus or add a taskbar button'}
$near=Get-MenuDragResult 100 100 102 102 40 180
$far=Get-MenuDragResult 100 100 120 130 40 180
$dpi=Get-MenuDragResult 100 100 120 140 40 180 2 2
if($near.Dragged -or -not $far.Dragged -or $far.X -ne 60 -or $far.Y -ne 210 -or $dpi.X -ne 50 -or $dpi.Y -ne 200){throw 'Floating menu drag threshold/DPI geometry failed'}
$path=Join-Path $env:TEMP ('fox-menu-'+[guid]::NewGuid().ToString('N')+'.json')
$saved=Load-Xaml 'Controls.xaml';$saved.FindName('FloatingMenuX').Value=-300;$saved.FindName('FloatingMenuY').Value=450
try{
    Save-HudSettings $saved $path;$loaded=Load-Xaml 'Controls.xaml';Load-HudSettings $loaded $path
    if($loaded.FindName('FloatingMenuX').Value -ne -300 -or $loaded.FindName('FloatingMenuY').Value -ne 450){throw 'Floating menu position persistence failed'}
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
$controls=Load-Xaml 'Controls.xaml'
try{
    Initialize-FloatingMenu -HiddenTest
    if($null -eq $script:menuFocus -or $script:menuBubble.IsVisible -or $script:menuBubble.FindName('LogoFallback').Visibility -ne 'Collapsed'){throw 'Floating logo initialization failed'}
}finally{if($script:menuFocus){$script:menuFocus.Dispose();$script:menuFocus=$null};if($script:menuBubble){$script:menuBubble.Close();$script:menuBubble=$null};$controls=$null}
Write-Output 'PASS: hidden HWND no-activate mouse contract, hotkey message dispatch, nonfocusable controls, popup-free ranges, logo initialization/drag DPI and saved position; no DCS full-screen test'
