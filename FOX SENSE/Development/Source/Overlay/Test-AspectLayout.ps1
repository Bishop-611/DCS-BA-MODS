# Exercise actual WPF transforms through the full-window Viewbox, including
# existing glyphs during resize, target anchors, labels, and custom size controls.
function Assert-AspectNear([double]$Actual,[double]$Expected,[string]$Message){
    if([Math]::Abs($Actual-$Expected) -gt 0.02){throw ($Message+': '+$Actual+' != '+$Expected)}
}
$viewbox=$hudWindow.Content
$camera=@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};right=@{x=0;y=0;z=1};up=@{x=0;y=1;z=0};projection=@{hfov_deg=90}}
$script:projectionScaleX=1;$script:projectionScaleY=1;$script:markerOffsetX=0;$script:markerOffsetY=0
$markerSlider=$null;$datalinkCheckbox=$null;$fovSlider=$null
$script:saAircraftTypes=$true
$testFrame=[pscustomobject]@{state='LIVE_POSITIONS';camera=$camera;own_heading=0;ownship=@{x=0;y=0;z=0};tracks=@(
    @{identity='FRIENDLY';age_s=0;aircraft_type='F-15C';p=@{x=10000;y=500;z=1200}},
    @{identity='HOSTILE';age_s=0;aircraft_type='MiG-29';p=@{x=10000;y=-500;z=-1200}})}
Set-DatalinkRange 60
foreach($dimensions in @(@(2560,1440),@(3440,1440),@(5120,1440),@(1920,1080),@(1920,1200),@(1280,1024),@(2752,1152),@(2560,1440))){
    $w=[double]$dimensions[0];$h=[double]$dimensions[1];$uniform=[Math]::Min($w/2560,$h/1440)
    Update-HudAspect $w $h;$script:viewportAspect=$w/$h
    foreach($size in @(0.6,1.0,1.8)){
        $script:aircraftSize=$size;Set-DatalinkFrame $testFrame;Draw-Datalink
        $viewbox.Measure([Windows.Size]::new($w,$h));$viewbox.Arrange([Windows.Rect]::new(0,0,$w,$h));$viewbox.UpdateLayout()
        foreach($index in @(0,1)){
            $shape=$trackCanvas.Children[2*$index];$label=$trackCanvas.Children[2*$index+1]
            $t=$shape.TransformToAncestor($viewbox)
            $radius=if($index -eq 0){12*$size}else{12}
            $center=$t.Transform([Windows.Point]::new($radius,$radius))
            $right=$t.Transform([Windows.Point]::new(2*$radius,$radius));$bottom=$t.Transform([Windows.Point]::new($radius,2*$radius))
            $projected=Get-ViewProjection $camera $testFrame.tracks[$index].p
            Assert-AspectNear $center.X ($projected.X*$w/2560) 'Projected target X moved'
            Assert-AspectNear $center.Y ($projected.Y*$h/1440) 'Projected target Y moved'
            Assert-AspectNear ($right.X-$center.X) (12*$size*$uniform) 'Symbol horizontal size'
            Assert-AspectNear ($bottom.Y-$center.Y) (12*$size*$uniform) 'Symbol vertical size'
            $lt=$label.TransformToAncestor($viewbox);$origin=$lt.Transform([Windows.Point]::new(0,0))
            Assert-AspectNear ($origin.X-$center.X) (22*$size*$uniform) 'Label offset stretched'
            $a=$lt.Transform([Windows.Point]::new(10,0));$b=$lt.Transform([Windows.Point]::new(0,10))
            Assert-AspectNear ($a.X-$origin.X) ($b.Y-$origin.Y) 'Text stretched'
        }
    }
}
# The map retains its user scale; the same existing visual updates on resize.
$rwrCueCanvas.Children.Clear();$script:rwrSize=1.4
Draw-HornetRwrSymbol ([pscustomobject]@{X=1800;Y=600;Edge=0}) '29' 'lock'
$rwrGlyph=$rwrCueCanvas.Children[0]
$panel=$hudWindow.FindName('FlightData');$panel.Visibility='Visible'
$speed=$hudWindow.FindName('SpeedBox');$speed.Visibility='Visible'
Set-FlightDataScale 1.25
$script:datalinkOverlayEnabled=$true;$script:datalinkOverlayScale=1.6
Draw-DatalinkOverlay;$map=$datalinkOverlayCanvas.Children[0]
foreach($dimensions in @(@(3440,1440),@(1280,1024),@(2560,1440))){
    $w=[double]$dimensions[0];$h=[double]$dimensions[1];Update-HudAspect $w $h
    $viewbox.Measure([Windows.Size]::new($w,$h));$viewbox.Arrange([Windows.Rect]::new(0,0,$w,$h));$viewbox.UpdateLayout()
    $t=$map.TransformToAncestor($viewbox);$o=$t.Transform([Windows.Point]::new(0,0));$x=$t.Transform([Windows.Point]::new(420,0));$y=$t.Transform([Windows.Point]::new(0,420))
    Assert-AspectNear ($x.X-$o.X) ($y.Y-$o.Y) 'SA map stretched after resize'
    Assert-AspectNear ($x.X-$o.X) (420*1.6*[Math]::Min($w/2560,$h/1440)) 'Map scale changed'
    $rt=$rwrGlyph.TransformToAncestor($viewbox);$rc=$rt.Transform([Windows.Point]::new(40,40))
    Assert-AspectNear $rc.X (1800*$w/2560) 'RWR cue center moved'
    Assert-AspectNear $rc.Y (600*$h/1440) 'RWR cue center moved'
    foreach($element in @($rwrGlyph,$speed)){
        $et=$element.TransformToAncestor($viewbox);$eo=$et.Transform([Windows.Point]::new(0,0));$ex=$et.Transform([Windows.Point]::new(10,0));$ey=$et.Transform([Windows.Point]::new(0,10))
        Assert-AspectNear ($ex.X-$eo.X) ($ey.Y-$eo.Y) 'RWR or flight instrument stretched'
    }
}
Set-FlightDataScale 1;$script:rwrSize=1
Update-HudAspect 2560 1440;$script:viewportAspect=16.0/9;$script:aircraftSize=1
$script:datalinkOverlayEnabled=$false;$script:datalinkOverlayScale=1
Write-Output 'PASS: actual WPF target/label geometry at 16:9, 3440x1440, 32:9, 16:10, 5:4 and scaled desktop; projected centers, symbol sizes, map scale and live resize retained'
