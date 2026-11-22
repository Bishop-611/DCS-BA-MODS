$script:lastSaPaint=[datetime]::MinValue
$script:datalinkOverlayEnabled=$false
$script:datalinkOverlayX=180;$script:datalinkOverlayY=880
$script:datalinkOverlayScale=1.0
$script:saAircraftTypes=$true
function Get-SaAircraftTypeLabel($Track){
    # Use only an explicit simulator type, never a callsign, coalition, or radar guess.
    $model=[string]$Track.aircraft_type
    if([string]::IsNullOrWhiteSpace($model) -or $model.Length -gt 96 -or $model -match '[\x00-\x1f]' -or $model -match '^(?i:unknown|nil|null|none|u)$'){return ''}
    if($model -match '^(?i:FA-18|F/A-18|F-18)') {return 'F/A-18'}
    if($model -match '^(?i:F-\d+|MiG-\d+|Su-\d+|A-\d+|B-\d+|Tu-\d+|Il-\d+|E-\d+|C-\d+|KC-\d+|UH-\d+|AH-\d+|Mi-\d+|Ka-\d+|CH-\d+)'){return $matches[0]}
    if($model.Length -le 18){return $model}
    return $model.Substring(0,17)+'…'
}
function New-SaContactSymbol([string]$Identity){
    # Independently drawn Hornet-inspired shapes; no onboard/offboard fusion is asserted.
    $glyph=New-Object Windows.Controls.Canvas;$glyph.Width=20;$glyph.Height=20;$glyph.Tag='DatalinkContact'
    $line=New-Object Windows.Shapes.Polyline
    if($Identity -eq 'FRIENDLY'){
        $points=New-Object Windows.Media.PointCollection
        foreach($i in 0..18){$a=$i*[Math]::PI/18;$points.Add([Windows.Point]::new(10-8*[Math]::Cos($a),12-8*[Math]::Sin($a)))}
        $line.Points=$points
    }else{$line.Points=[Windows.Media.PointCollection]::Parse('2,12 10,3 18,12')}
    $line.Stroke='#83FF9B';$line.StrokeThickness=1.8;[void]$glyph.Children.Add($line)
    return $glyph
}
function New-SaCompass($Heading){
    $rose=New-Object Windows.Controls.Canvas;$rose.Tag='SaCompass'
    if($null -eq $Heading){return $rose}
    $headingValue=[double]$Heading
    if([double]::IsNaN($headingValue) -or [double]::IsInfinity($headingValue)){return $rose}
    foreach($bearing in 0..35){
        $angle=$bearing*[Math]::PI/18-$headingValue
        $outer=160;$inner=if($bearing%3 -eq 0){151}else{156}
        $tick=New-Object Windows.Shapes.Line;$tick.Stroke='#83FF9B';$tick.StrokeThickness=1
        $tick.X1=210+$inner*[Math]::Sin($angle);$tick.Y1=210-$inner*[Math]::Cos($angle)
        $tick.X2=210+$outer*[Math]::Sin($angle);$tick.Y2=210-$outer*[Math]::Cos($angle)
        [void]$rose.Children.Add($tick)
        if($bearing%3 -eq 0){
            $label=New-Object Windows.Controls.TextBlock;$label.Text=('{0:00}' -f $bearing);$label.Width=26;$label.TextAlignment='Center';$label.FontSize=12
            [Windows.Controls.Canvas]::SetLeft($label,(197+178*[Math]::Sin($angle)))
            [Windows.Controls.Canvas]::SetTop($label,(202-178*[Math]::Cos($angle)))
            [void]$rose.Children.Add($label)
        }
    }
    return $rose
}
function Get-DatalinkMapPoint($Frame,$Track){
 if($Track.identity -notin @('FRIENDLY','HOSTILE') -or $null -eq $Frame.ownship -or $null -eq $Frame.own_heading -or $null -eq $Track.p){return $null}
 try{
  $h=[double]$Frame.own_heading;if([double]::IsNaN($h) -or [double]::IsInfinity($h)){return $null}
  $d=@{};foreach($a in @('x','y','z')){if($null -eq $Track.p.$a -or $null -eq $Frame.ownship.$a){return $null};$n=[double]$Track.p.$a-[double]$Frame.ownship.$a;if([double]::IsNaN($n) -or [double]::IsInfinity($n)){return $null};$d[$a]=$n}
  $v=[FoxGeometry]::B($d.x,$d.y,$d.z,$h,$script:markerRangeM)
  if($null -eq $v){return $null};return [pscustomobject]@{X=$v[0];Y=$v[1]}
 }catch{return $null}
}
function Draw-DatalinkOverlay([switch]$RateLimited) {
    $nowMap=[datetime]::UtcNow
    if($RateLimited -and ($nowMap-$script:lastSaPaint).TotalMilliseconds -lt (1000.0/60.0)){return}
    $script:lastSaPaint=$nowMap
    Sync-DatalinkRangeFromControls
    $datalinkOverlayCanvas.Children.Clear()
    if(-not $script:datalinkOverlayEnabled){return}
    $map=New-Object Windows.Controls.Canvas
    $map.Width=420;$map.Height=420;$map.Background='#B8101814'
    $scale=[Math]::Max(0.5,[Math]::Min(2.0,[double]$script:datalinkOverlayScale))
    $map.RenderTransform=[Windows.Media.ScaleTransform]::new($scale,$scale)
    Set-HudAspectTransform $map
    [Windows.Controls.Canvas]::SetLeft($map,[Math]::Min($script:datalinkOverlayX,(2560-420*$scale)))
    [Windows.Controls.Canvas]::SetTop($map,[Math]::Min($script:datalinkOverlayY,(1440-420*$scale)))
    [void]$datalinkOverlayCanvas.Children.Add($map)
    foreach($r in @(80,160)){
        $ring=New-Object Windows.Shapes.Ellipse;$ring.Width=2*$r;$ring.Height=2*$r
        $ring.Stroke='#50835D';$ring.StrokeThickness=1
        [Windows.Controls.Canvas]::SetLeft($ring,(210-$r));[Windows.Controls.Canvas]::SetTop($ring,(210-$r))
        [void]$map.Children.Add($ring)
    }
    $own=New-Object Windows.Controls.Canvas;$own.Tag='SaOwnship';$own.SnapsToDevicePixels=$true
    foreach($coords in @(@(200,210,220,210),@(210,200,210,220))){
        $line=New-Object Windows.Shapes.Line;$line.X1=$coords[0];$line.Y1=$coords[1];$line.X2=$coords[2];$line.Y2=$coords[3]
        $line.Stroke='#83FF9B';$line.StrokeThickness=1.5;$line.SnapsToDevicePixels=$true;[void]$own.Children.Add($line)
    }
    [void]$map.Children.Add($own)
    $title=New-Object Windows.Controls.TextBlock;$title.Tag='SaRangeTitle';$title.Text=('SA / RWR {0:0} NM' -f ($script:markerRangeM/1852.0));$title.FontSize=16;$title.Width=384;$title.TextAlignment='Right'
    if($null -ne $controls){
        $rangeControl=$controls.FindName('DatalinkRange')
        $rwrRangeControl=$controls.FindName('AlertRangeNm')
        if($rangeControl -and $rwrRangeControl){
            $binding=[Windows.Data.MultiBinding]::new();$binding.StringFormat='SA / RWR {0} NM'
            $saBinding=[Windows.Data.Binding]::new('SelectedValue');$saBinding.Source=$rangeControl;$saBinding.Mode=[Windows.Data.BindingMode]::OneWay
            $rwrBinding=[Windows.Data.Binding]::new('Value');$rwrBinding.Source=$rwrRangeControl;$rwrBinding.Mode=[Windows.Data.BindingMode]::OneWay
            [void]$binding.Bindings.Add($saBinding);[void]$binding.Bindings.Add($rwrBinding)
            [void][Windows.Data.BindingOperations]::SetBinding($title,[Windows.Controls.TextBlock]::TextProperty,$binding)
        }
    }
    [Windows.Controls.Canvas]::SetLeft($title,18);[Windows.Controls.Canvas]::SetTop($title,12);[void]$map.Children.Add($title)
    $message='NO LIVE POSITION DATA';$count=0
    $f=$script:dlFrame;$age=Get-DatalinkWorldAge
    [void]$map.Children.Add((New-SaCompass $(if($null -ne $f -and $age -le 1){$f.own_heading}else{$null})))
    if($null -ne $f -and $age -le 1){
        if($f.state -in @('OWN_EXPORT_BLOCKED','OBJECT_EXPORT_BLOCKED')){$message='EXPORT BLOCKED'}
        elseif($null -eq $f.ownship -or $null -eq $f.own_heading){$message='NO OWNSHIP / HEADING'}
        else{
            foreach($t in @($f.tracks)){
                if($null -eq $t.age_s){continue}
                $trackAge=[double]$t.age_s
                if([double]::IsNaN($trackAge) -or [double]::IsInfinity($trackAge) -or $trackAge -lt 0 -or $trackAge+$age -gt 1){continue}
                $p=Get-DatalinkMapPoint $f $t
                if($null -eq $p){continue}
                $shape=New-SaContactSymbol $t.identity
                [Windows.Controls.Canvas]::SetLeft($shape,($p.X-10));[Windows.Controls.Canvas]::SetTop($shape,($p.Y-10));[void]$map.Children.Add($shape);$count++
                if($script:saAircraftTypes){
                    $typeText=Get-SaAircraftTypeLabel $t
                    if($typeText){
                        $label=New-Object Windows.Controls.TextBlock;$label.Tag='SaAircraftType';$label.Text=$typeText;$label.FontSize=11;$label.Foreground='#83FF9B'
                        $label.Background='#CC101814';$label.Padding=[Windows.Thickness]::new(2,0,2,0)
                        $label.Measure([Windows.Size]::new([double]::PositiveInfinity,[double]::PositiveInfinity))
                        [Windows.Controls.Canvas]::SetLeft($label,$(if($p.X -gt 280){$p.X-$label.DesiredSize.Width-13}else{$p.X+13}))
                        [Windows.Controls.Canvas]::SetTop($label,($p.Y+4));[void]$map.Children.Add($label)
                    }
                }
            }
            $message=if($script:dlDemo){'SA STYLE / DEMO / NOT LIVE'}else{'SA STYLE / '+$count+' TRACKS / EXPORT'}
        }
    }
    if($null -ne $f -and $age -le 1){[void]$map.Children.Add((New-SaMissileLayer $f))}
    if($script:saRwrEnabled){[void]$map.Children.Add((New-SaRwrLayer))}
    # Operational/source state remains in runtime diagnostics, not over the flight view.
}
