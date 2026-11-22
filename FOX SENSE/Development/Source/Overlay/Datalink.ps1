# Track projection is separate from RWR's coarse clock sectors.
$script:dlLast=[datetime]::MinValue
$script:dlFrame=$null
$script:dlDemo=$false
$script:fontFactor=1.0
$script:contentScale=1.0
$script:aircraftSize=1.0
$script:missileSize=1.0
$script:rwrSize=1.0
$script:projectionScaleX=1.0
$script:rwrProjectionZoom=1.0
$script:missileProjectionZoom=1.0
$script:projectionScaleY=1.0
$script:markerOffsetX=0.0
$script:markerOffsetY=0.0
$script:markerRangeM=20*1852.0
function Set-DatalinkRange([int]$Nm){
    if($Nm -notin @(20,40,60)){$Nm=20}
    $script:markerRangeM=$Nm*1852.0
}
function Sync-DatalinkRangeFromControls {
    if($null -eq $controls){return}
    $choice=$controls.FindName('DatalinkRange')
    if($choice -and [string]$choice.SelectedValue -in @('20','40','60')){Set-DatalinkRange ([int]$choice.SelectedValue);Set-AlertRange ([int]$choice.SelectedValue)}
}
function Select-DatalinkRange([int]$Nm){
    if($Nm -notin @(20,40,60)){return}
    if($null -ne $controls){
        $controls.FindName('DatalinkRange').SelectedValue=[string]$Nm
        $controls.FindName('DatalinkRangeValue').Text=('{0} NM' -f $Nm)
        foreach($n in @(20,40,60)){$controls.FindName(('Range'+$n)).FontWeight=if($n -eq $Nm){'Bold'}else{'Normal'}}
    }
    Set-DatalinkRange $Nm
    Set-AlertRange $Nm
    if($null -ne $controls){Update-RangeHighlights}
    Draw-Datalink;Draw-DatalinkOverlay
    if($script:settingsReady -and $null -ne $controls){Save-HudSettings $controls $settingsPath}
}
function Connect-DatalinkRangeButtons($Controls){
    $Controls.FindName('Range20').Add_Click({Select-DatalinkRange 20})
    $Controls.FindName('Range40').Add_Click({Select-DatalinkRange 40})
    $Controls.FindName('Range60').Add_Click({Select-DatalinkRange 60})
}
$script:viewportAspect=2560.0/1440.0
function Get-TrackProjection($Camera,$Position,[double]$HorizontalFov=90){
    $p=Get-ViewProjection $Camera $Position $HorizontalFov
    if($null -eq $p -or $p.Forward -le 1){return $null}
    $x=1280+($p.X-1280)*$script:projectionScaleX+$script:markerOffsetX
    $y=720+($p.Y-720)*$script:projectionScaleY+$script:markerOffsetY
    if($x -lt 70 -or $x -gt 2490 -or $y -lt 110 -or $y -gt 1280){return $null}
    return [pscustomobject]@{X=$x;Y=$y}
}
function ConvertFrom-DatalinkLine([string]$Line,[string]$Prefix='F4DL_V1|'){
    $index=$Line.IndexOf($Prefix)
    if($index -lt 0 -or $Line.Length -gt 65536){return $null}
    try{
        $frame=$Line.Substring($index+$Prefix.Length) | ConvertFrom-Json
        if($Prefix -eq 'F4CAM_V1|'){$frame|Add-Member -NotePropertyName tracks -NotePropertyValue @() -Force}
        if($frame.state -notin @('OWN_EXPORT_BLOCKED','SENSOR_EXPORT_BLOCKED','NO_SHARED_FEED','SENSOR_TRACKS','EXTERNAL_TRACKS','OBJECT_EXPORT_BLOCKED','NO_AIRCRAFT','LIVE_POSITIONS','DEMO')){return $null}
        if(@($frame.tracks).Count -gt 32){return $null}
        foreach($t in @($frame.tracks)){
            if($null -eq $t -or $t.identity -notin @('FRIENDLY','HOSTILE','UNKNOWN')){return $null}
            if($t.source -notin @('wing_api','own_sensor','awacs','wingman','server','world_export','demo')){return $null}
            if($null -eq $t.age_s){return $null}
            $age=[double]$t.age_s
            if([double]::IsNaN($age) -or [double]::IsInfinity($age) -or $age -lt 0 -or $age -gt 30){return $null}
        }
        return $frame
    }catch{return $null}
}
function Set-DatalinkFrame($Frame,[bool]$Synthetic=$false){
    $Frame|Add-Member -NotePropertyName TrackReceivedUtc -NotePropertyValue ([datetime]::UtcNow) -Force
    $script:dlFrame=$Frame;$script:dlDemo=$Synthetic;$script:dlLast=[datetime]::UtcNow
}
function Set-CameraFrame($Frame){
    if($null -eq $script:dlFrame){$Frame|Add-Member -NotePropertyName tracks -NotePropertyValue @() -Force;$script:dlFrame=$Frame}
    if([long]$Frame.sequence -lt [long]$script:dlFrame.sequence){return}
    foreach($key in @('sequence','state','camera','ownship','flight','own_heading','own_unit_name','own_unit_id')){
        $script:dlFrame|Add-Member -NotePropertyName $key -NotePropertyValue $Frame.$key -Force
    }
    $script:dlLast=[datetime]::UtcNow
}
function Get-DatalinkWorldAge {
    $age=([datetime]::UtcNow-$script:dlLast).TotalSeconds
    if($null -ne $script:dlFrame.TrackReceivedUtc){$age=[Math]::Max($age,([datetime]::UtcNow-$script:dlFrame.TrackReceivedUtc).TotalSeconds)}
    return $age
}
function Draw-Datalink {
    Sync-DatalinkRangeFromControls
    $trackCanvas.Children.Clear()
    if($null -ne $datalinkCheckbox -and -not $datalinkCheckbox.IsChecked){$dlStatus.Text="";return}
    if(([datetime]::UtcNow-$script:dlLast).TotalSeconds -gt 3){$dlStatus.Text='NO LIVE POSITION DATA';return}
    $frame=$script:dlFrame
    if($null -eq $frame){$dlStatus.Text='NO LIVE POSITION DATA';return}
    $dlStatus.Text=if($script:dlDemo){'DEMO - NOT LIVE'}else{
        switch($frame.state){
            OBJECT_EXPORT_BLOCKED {'SERVER POSITION EXPORT UNAVAILABLE'}
            OWN_EXPORT_BLOCKED {'CAMERA EXPORT UNAVAILABLE'}
            NO_AIRCRAFT {'NO AIRCRAFT POSITIONS REPORTED'}
            default {('DATALINK / {0:0} NM / MANUAL CALIBRATION' -f ($script:markerRangeM/1852.0))}
        }
    }
    if($null -eq $frame.camera){$dlStatus.Text+=' / NO CAMERA';return}
    $fov=if($null -ne $fovSlider){$fovSlider.Value}else{90}
    $size=$(if($null -ne $markerSlider){$markerSlider.Value}else{1})*$script:aircraftSize
    foreach($t in @($frame.tracks)){
        if($null -eq $t -or $t.identity -notin @('FRIENDLY','HOSTILE')){continue}
        if([double]$t.age_s+(Get-DatalinkWorldAge) -gt 1){continue}
        if($null -eq $frame.ownship -or $null -eq $t.p){continue}
        $rangeSquared=0.0;$rangeValid=$true
        foreach($axis in @('x','y','z')){
            if($null -eq $frame.ownship.$axis -or $null -eq $t.p.$axis){$rangeValid=$false;break}
            try{$delta=[double]$t.p.$axis-[double]$frame.ownship.$axis}catch{$rangeValid=$false;break}
            if([double]::IsNaN($delta) -or [double]::IsInfinity($delta)){$rangeValid=$false;break}
            $rangeSquared+=$delta*$delta
        }
        if(-not $rangeValid -or $rangeSquared -gt $script:markerRangeM*$script:markerRangeM){continue}
        $p=Get-TrackProjection $frame.camera $t.p $fov
        if($null -eq $p){continue}
        if($t.identity -eq 'FRIENDLY'){
            $shape=New-Object Windows.Shapes.Ellipse
            $shape.Width=24*$size;$shape.Height=24*$size;$shape.Stroke='#83FF9B'
        }else{
            $shape=New-Object Windows.Shapes.Polygon
            $shape.Points=[Windows.Media.PointCollection]::Parse('12,0 24,12 12,24 0,12')
            $shape.LayoutTransform=[Windows.Media.ScaleTransform]::new($size,$size)
            $shape.Stroke='#83FF9B'
        }
        $shape.StrokeThickness=1.5;$shape.Fill=[Windows.Media.Brushes]::Transparent
        [Windows.Controls.Canvas]::SetLeft($shape,$p.X-12*$size)
        [Windows.Controls.Canvas]::SetTop($shape,$p.Y-12*$size)
        Set-HudAspectTransform $shape (12*$size) (12*$size)
        [void]$trackCanvas.Children.Add($shape)
        $shortType=Get-SaAircraftTypeLabel $t
        if($shortType){
            $label=New-Object Windows.Controls.TextBlock
            $label.Text=$shortType;$label.FontFamily=$script:instrumentFont;$label.FontSize=20*$size;$label.Foreground='#83FF9B'
            [Windows.Controls.Canvas]::SetLeft($label,$p.X+22*$size)
            [Windows.Controls.Canvas]::SetTop($label,$p.Y-12*$size)
            Set-HudAspectTransform $label (-22*$size) (12*$size)
            [void]$trackCanvas.Children.Add($label)
        }
    }
}
function New-DatalinkDemo([int]$Step){
    $a=[Math]::Sin($Step/28.0)*0.28
    $camera=[pscustomobject]@{p=@{x=0;y=6000;z=0};forward=@{x=[Math]::Cos($a);y=0;z=[Math]::Sin($a)};up=@{x=0;y=1;z=0};right=@{x=-[Math]::Sin($a);y=0;z=[Math]::Cos($a)}}
    [pscustomobject]@{state='DEMO';camera=$camera;own_heading=0;ownship=@{x=0;y=6000;z=0};tracks=@(
        @{id='VIPER_12';identity='FRIENDLY';source='demo';age_s=0;p=@{x=22000;y=6500;z=-8500}},
        @{id='TRACK_204';identity='HOSTILE';source='demo';age_s=0;p=@{x=28000;y=8200;z=8000}},
        @{id='TRACK_781';identity='UNKNOWN';source='demo';age_s=0;p=@{x=36000;y=5200;z=1800}}
    )}
}




# Azimuth-only cue: Jester clock sector is not a precise target LOS or elevation.
function Get-RwrAzimuthCue($Camera,$Heading,[double]$Hour,[double]$HorizontalFov=90,[double]$Zoom=1){
 if($null -eq $Camera -or $null -eq $Camera.forward -or $null -eq $Heading -or $Hour -lt 1 -or $Hour -gt 12){return $null}
 try{$h=[double]$Heading;$fx=[double]$Camera.forward.x;$fz=[double]$Camera.forward.z}catch{return $null}
 foreach($n in @($h,$fx,$fz,$HorizontalFov,$Zoom)){if([double]::IsNaN($n) -or [double]::IsInfinity($n)){return $null}}
 if($fx*$fx+$fz*$fz -lt 0.01 -or $HorizontalFov -lt 30 -or $HorizontalFov -gt 140 -or $Zoom -le 0){return $null}
 $roll=0.0
 if($null -ne $Camera.right -and $null -ne $Camera.up){$ry=[double]$Camera.right.y;$uy=[double]$Camera.up.y;if(-not [double]::IsNaN($ry) -and -not [double]::IsNaN($uy)){$roll=[Math]::Atan2($ry,$uy)}}
 $v=[FoxGeometry]::A($h,$fx,$fz,$roll,$Hour,$Zoom)
 return [pscustomobject]@{X=$v[0];Y=$v[1];Edge=0;Angle=$v[2];Layout='HELMET_CLOCK'}
}
function Draw-RwrCue {
    $rwrCueCanvas.Children.Clear()
    $e=$script:receiverEvent
    if($null -eq $e -or $e.Mode -notin @('CONTACT','LAUNCH') -or ([datetime]::UtcNow-$script:lastEvent).TotalSeconds -gt 8){return}
    if(([datetime]::UtcNow-$script:dlLast).TotalSeconds -gt 1){return}
    $frame=$script:dlFrame
    if($null -eq $frame){return}
    $fov=if($null -ne $fovSlider){$fovSlider.Value}else{90}
    $cue=Get-RwrAzimuthCue $frame.camera $frame.own_heading $e.Hour $fov $script:projectionScaleX
    if($null -eq $cue){return}
    $color=if($e.Mode -eq 'LAUNCH'){'#FF7878'}else{'#83FF9B'}
    $symbol=New-Object Windows.Controls.StackPanel
    $tag=New-Object Windows.Controls.TextBlock
    $kind=switch($e.Category){airborne{'AIR'};surface{'SAM'};default{'RWR'}}
    $tag.Text=if($cue.Edge -lt 0){'< '+$kind}elseif($cue.Edge -gt 0){$kind+' >'}else{$kind}
    $tag.Foreground=$color;$tag.FontFamily=$script:instrumentFont;$tag.FontSize=16*$script:fontFactor
    $tag.TextAlignment='Center'
    $box=New-Object Windows.Controls.Border
    $box.BorderBrush=$color;$box.BorderThickness=[Windows.Thickness]::new(1.5)
    $box.Padding=[Windows.Thickness]::new(5*$script:aircraftSize)
    $box.Child=$tag;[void]$symbol.Children.Add($box)
    $caption=New-Object Windows.Controls.TextBlock
    $caption.Text=if($e.Mode -eq 'LAUNCH'){'LAUNCH / AZ ONLY'}else{'AZ ONLY / +/-15 DEG'}
    $caption.Foreground=$color;$caption.FontSize=10*$script:fontFactor;$caption.TextAlignment='Center'
    [void]$symbol.Children.Add($caption)
    $symbol.Measure([Windows.Size]::new(500,200))
    [Windows.Controls.Canvas]::SetLeft($symbol,($cue.X-$symbol.DesiredSize.Width/2))
    [Windows.Controls.Canvas]::SetTop($symbol,$cue.Y)
    if($e.Mode -eq 'LAUNCH'){$symbol.Opacity=if($script:flash){1}else{0.25}}
    Set-HudAspectTransform $symbol ($symbol.DesiredSize.Width/2) 0
    [void]$rwrCueCanvas.Children.Add($symbol)
}
