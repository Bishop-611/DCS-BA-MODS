# Keep normalized full-window projection, but scale symbol artwork uniformly.
# All symbols share one live transform so resize/DPI updates affect existing
# markers and static instruments without rebuilding the canvas or changing FOV.
$script:hudAspectScale=[Windows.Media.ScaleTransform]::new(1,1)
function Update-HudAspect([double]$Width,[double]$Height){
    if($Width -le 0 -or $Height -le 0 -or [double]::IsNaN($Width) -or [double]::IsNaN($Height) -or [double]::IsInfinity($Width) -or [double]::IsInfinity($Height)){return}
    $sx=$Width/2560.0;$sy=$Height/1440.0
    $uniform=[Math]::Min($sx,$sy)
    $script:hudAspectScale.ScaleX=$uniform/$sx
    $script:hudAspectScale.ScaleY=$uniform/$sy
}
function Set-HudAspectTransform($Element,[double]$AnchorX=0,[double]$AnchorY=0){
    $group=[Windows.Media.TransformGroup]::new()
    if(-not $Element.RenderTransform.Value.IsIdentity){[void]$group.Children.Add($Element.RenderTransform)}
    [void]$group.Children.Add([Windows.Media.TranslateTransform]::new(-$AnchorX,-$AnchorY))
    [void]$group.Children.Add($script:hudAspectScale)
    [void]$group.Children.Add([Windows.Media.TranslateTransform]::new($AnchorX,$AnchorY))
    $Element.RenderTransform=$group
}
