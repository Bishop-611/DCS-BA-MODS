function Get-ShortMissileName([string]$Name){
    $n=$Name.ToUpperInvariant().Replace('_','-')
    foreach($pattern in @('5V55','5V28','48N6','40N6','9M\d{2,3}[A-Z0-9]*','(?:AIM|AGM|RIM|MIM|FIM)-?\d{1,3}[A-Z0-9]*','(?:^|[^A-Z0-9])(R)-?(\d{2}[A-Z0-9]*)','(?:PL|SD)-?\d{1,2}[A-Z0-9]*')){
        if($n -match $pattern){
            if($Matches[1] -eq 'R'){return 'R-'+$Matches[2]}
            return ($Matches[0] -replace '^(AIM|AGM|RIM|MIM|FIM|PL|SD)(\d)','$1-$2')
        }
    }
    if($n -match '(^|[^A-Z])MAGIC[^A-Z]*2'){return 'MAGIC 2'}
    if($n -match '(^|[^A-Z])MICA[^A-Z]*(IR|EM)'){return 'MICA '+$Matches[2]}
    return 'M'
}
function Test-MissileMarkerInbound([string]$Id){
    $sample=$script:incomingSamples[$Id]
    return $null -ne $sample -and $sample.Incoming -and $null -ne $script:incomingMarkerLast -and ([datetime]::UtcNow-$script:incomingMarkerLast).TotalSeconds -le 1.5
}
# Frozen geometry is shared across frames and between the helmet and SA page.
$script:missileSolidGeometry=[Windows.Media.Geometry]::Parse('M 0,-14 L 13,10 -13,10 Z')
$script:missileBrokenGeometry=[Windows.Media.Geometry]::Parse('M -3.64,-7.28 L 0,-14 3.64,-7.28 M 9.36,3.28 L 13,10 5.72,10 M -5.72,10 L -13,10 -9.36,3.28')
$script:missileSolidGeometry.Freeze();$script:missileBrokenGeometry.Freeze()
function New-HornetMissileShape([bool]$Inbound,[double]$Scale=1){
    $shape=New-Object Windows.Shapes.Path
    $shape.Data=if($Inbound){$script:missileSolidGeometry}else{$script:missileBrokenGeometry}
    $shape.Tag=if($Inbound){'Inbound'}else{'Detected'}
    $shape.Stroke='#FF5050';$shape.StrokeThickness=1.7
    $shape.RenderTransform=[Windows.Media.ScaleTransform]::new($Scale,$Scale)
    return $shape
}
function Set-FlightDataScale([double]$Scale){
    if([double]::IsNaN($Scale) -or [double]::IsInfinity($Scale)){$Scale=1}
    $Scale=[Math]::Max(0.5,[Math]::Min(1.5,$Scale))
    $panel=$hudWindow.FindName('FlightData')
    if($panel.RenderTransform -isnot [Windows.Media.ScaleTransform]){
        $panel.RenderTransform=[Windows.Media.ScaleTransform]::new($Scale,$Scale,1280,720)
    }else{
        $panel.RenderTransform.ScaleX=$Scale;$panel.RenderTransform.ScaleY=$Scale
    }
}
$script:flightDataEnabled=$true
function Update-HornetFlightData {
    $panel=$hudWindow.FindName('FlightData')
    if($null -eq $panel){return}
    if(-not $script:flightDataEnabled){$panel.Visibility='Collapsed';return}
    $f=$script:dlFrame
    if($null -eq $f -or ([datetime]::UtcNow-$script:dlLast).TotalSeconds -gt 1){$panel.Visibility='Collapsed';return}
    $panel.Visibility='Visible'
    $values=@{OwnHeading='';OwnSpeed='';OwnAltitude='';OwnAlpha='';OwnMach='';OwnG=''}
    if($null -ne $f.own_heading){$h=[double]$f.own_heading*180/[Math]::PI;if(-not [double]::IsNaN($h) -and -not [double]::IsInfinity($h)){$values.OwnHeading='HDG {0:000}' -f (([Math]::Round($h)%360+360)%360)}}
    $a=$f.flight
    foreach($spec in @(@('ias','OwnSpeed',1.943844,'{0:0}'),@('altitude','OwnAltitude',3.28084,'{0:0}'),@('aoa','OwnAlpha',1,([string][char]0x03B1+'  {0:0.0}'+[char]0x00B0)),@('mach','OwnMach',1,'M  {0:0.00}'),@('g','OwnG',1,'G  {0:0.0}'))){
        if($null -ne $a -and $null -ne $a.($spec[0])){
            $n=[double]$a.($spec[0]);if(-not [double]::IsNaN($n) -and -not [double]::IsInfinity($n)){$values[$spec[1]]=$spec[3] -f ($n*$spec[2])}
        }
    }
    # Export AGL is terrain clearance, not the simulated radar-altimeter instrument.
    $radarMarker=$hudWindow.FindName('AltitudeRadarMarker')
    $radarMarker.Visibility='Collapsed'
    if($null -ne $a -and $null -ne $a.agl){
        $agl=[double]$a.agl
        if(-not [double]::IsNaN($agl) -and -not [double]::IsInfinity($agl) -and $agl -ge 0 -and $agl -lt 152.4){
            $values.OwnAltitude='{0:0}' -f ($agl*3.280839895)
            $radarMarker.Visibility='Visible'
        }
    }
    foreach($key in $values.Keys){$hudWindow.FindName($key).Text=$values[$key]}
    $hudWindow.FindName('SpeedBox').Visibility=if($values.OwnSpeed){'Visible'}else{'Collapsed'}
    $hudWindow.FindName('AltitudeBox').Visibility=if($values.OwnAltitude){'Visible'}else{'Collapsed'}
}
