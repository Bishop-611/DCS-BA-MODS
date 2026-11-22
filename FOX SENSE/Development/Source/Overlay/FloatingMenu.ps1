$script:menuBubble=$null;$script:menuFocus=$null
$script:menuDrag=$null;$script:menuWasDragged=$false
function Get-MenuDragResult([double]$StartX,[double]$StartY,[double]$PointerX,[double]$PointerY,[double]$OriginX,[double]$OriginY,[double]$DpiX=1,[double]$DpiY=1){
    $dx=($PointerX-$StartX)/$DpiX;$dy=($PointerY-$StartY)/$DpiY
    [pscustomobject]@{X=$OriginX+$dx;Y=$OriginY+$dy;Dragged=($dx*$dx+$dy*$dy -gt 16)}
}
function Set-MenuBubblePosition([double]$X,[double]$Y){
    $left=[Windows.SystemParameters]::VirtualScreenLeft;$top=[Windows.SystemParameters]::VirtualScreenTop
    $right=$left+[Windows.SystemParameters]::VirtualScreenWidth-58
    $bottom=$top+[Windows.SystemParameters]::VirtualScreenHeight-58
    $script:menuBubble.Left=[Math]::Max($left,[Math]::Min($right,$X))
    $script:menuBubble.Top=[Math]::Max($top,[Math]::Min($bottom,$Y))
}
function Place-ControlsNearBubble {
    if($null -eq $script:menuBubble){return}
    $left=[Windows.SystemParameters]::VirtualScreenLeft;$top=[Windows.SystemParameters]::VirtualScreenTop
    $right=$left+[Windows.SystemParameters]::VirtualScreenWidth
    $bottom=$top+[Windows.SystemParameters]::VirtualScreenHeight
    $x=$script:menuBubble.Left+64
    if($x+$controls.Width -gt $right){$x=$script:menuBubble.Left-$controls.Width-6}
    $controls.Left=[Math]::Max($left,$x)
    $controls.Top=[Math]::Max($top,[Math]::Min($script:menuBubble.Top,$bottom-$controls.Height))
}
function Initialize-FloatingMenu([switch]$HiddenTest) {
    $script:menuBubble=Load-Xaml 'FloatingMenu.xaml'
    $logo=Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'logo.png'
    if([IO.File]::Exists($logo)){
        $image=[Windows.Media.Imaging.BitmapImage]::new([uri]$logo)
        $brush=[Windows.Media.ImageBrush]::new($image);$brush.Stretch='UniformToFill'
        $script:menuBubble.FindName('LogoDisc').Fill=$brush
        $script:menuBubble.FindName('LogoFallback').Visibility='Collapsed'
    }
    Set-MenuBubblePosition $controls.FindName('FloatingMenuX').Value $controls.FindName('FloatingMenuY').Value
    $script:menuBubble.Add_SourceInitialized({
        $handle=[Windows.Interop.WindowInteropHelper]::new($script:menuBubble).Handle
        $script:menuFocus=[FoxControlsFocus]::new($handle,$false)
    })
    $script:menuBubble.Add_MouseLeftButtonDown({
        $cursor=[FoxControlsFocus]::CursorPosition()
        $source=[Windows.PresentationSource]::FromVisual($script:menuBubble)
        $script:menuDrag=@{X=$cursor.X;Y=$cursor.Y;Left=$script:menuBubble.Left;Top=$script:menuBubble.Top;DpiX=$source.CompositionTarget.TransformToDevice.M11;DpiY=$source.CompositionTarget.TransformToDevice.M22}
        $script:menuWasDragged=$false
        [void]$script:menuBubble.CaptureMouse();$args[1].Handled=$true
    })
    $script:menuBubble.Add_MouseMove({
        if($null -eq $script:menuDrag){return}
        $cursor=[FoxControlsFocus]::CursorPosition();$d=$script:menuDrag
        $result=Get-MenuDragResult $d.X $d.Y $cursor.X $cursor.Y $d.Left $d.Top $d.DpiX $d.DpiY
        if($result.Dragged){$script:menuWasDragged=$true}
        if($script:menuWasDragged){Set-MenuBubblePosition $result.X $result.Y}
    })
    $script:menuBubble.Add_MouseLeftButtonUp({
        if($null -eq $script:menuDrag){return}
        $script:menuDrag=$null;$script:menuBubble.ReleaseMouseCapture()
        if($script:menuWasDragged){
            $controls.FindName('FloatingMenuX').Value=$script:menuBubble.Left
            $controls.FindName('FloatingMenuY').Value=$script:menuBubble.Top
            Save-HudSettings $controls $settingsPath
            if($controls.IsVisible){Place-ControlsNearBubble}
        }else{Toggle-ControlsPanel}
        $args[1].Handled=$true
    })
    $script:menuBubble.Add_LostMouseCapture({$script:menuDrag=$null})
    if($HiddenTest){[void][Windows.Interop.WindowInteropHelper]::new($script:menuBubble).EnsureHandle()}
    else{$script:menuBubble.Show()}
}
