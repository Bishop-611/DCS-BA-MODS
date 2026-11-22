function Get-JesterMissileCue($Camera,$Position){
    $fov=if($null -ne $fovSlider){$fovSlider.Value}else{90}
    $point=Get-ViewProjection $Camera $Position $fov
    if($null -eq $point){return $null}
    $f=$point.Forward;$r=$point.Right;$u=$point.Up
    $x=1280;$y=720;$edge=''
    if($f -gt 1){
        $x=1280+($point.X-1280)*$script:missileProjectionZoom;$y=720+($point.Y-720)*$script:missileProjectionZoom
        if($x -lt 130 -or $x -gt 2430 -or $y -lt 160 -or $y -gt 1240){
            $scale=[Math]::Max([Math]::Abs(($x-1280)/1150),[Math]::Abs(($y-720)/520))
            $x=1280+($x-1280)/$scale;$y=720+($y-720)/$scale
            $edge=if([Math]::Abs(($x-1280)/1150) -ge [Math]::Abs(($y-720)/520)){if($r -lt 0){'<'}else{'>'}}else{if($u -gt 0){'^'}else{'v'}}
        }
    }else{
        $x=if($r -lt 0){130}else{2430};$y=720
        $edge=if($r -lt 0){'< AFT'}else{'AFT >'}
    }
    [pscustomobject]@{X=$x;Y=$y;Edge=$edge}
}
$script:jesterMissileFrame=$null
$script:jesterMissileLast=[datetime]::MinValue
function Test-JesterVector($P){
    if($null -eq $P){return $false}
    foreach($a in @('x','y','z')){
        if($null -eq $P.$a){return $false}
        try{$n=[double]$P.$a}catch{return $false}
        if([double]::IsNaN($n) -or [double]::IsInfinity($n) -or [Math]::Abs($n) -gt 1e12){return $false}
    }
    return $true
}
function ConvertFrom-JesterMissileLine([string]$Line){
    $prefix='F4JESTER_MISSILES_V1|';$index=$Line.IndexOf($prefix)
    if($index -lt 0 -or $Line.Length -gt 65536){return $null}
    try{
        $f=$Line.Substring($index+$prefix.Length)|ConvertFrom-Json
        if($f.state -notin @('AWARENESS','UNAVAILABLE') -or @($f.missiles).Count -gt 64){return $null}
        foreach($entry in @($f.missiles)){
            if($entry.identity -notin @('FRIENDLY','HOSTILE','UNKNOWN') -or -not (Test-JesterVector $entry.ned)){return $null}
            if($null -eq $entry.age_s){return $null}
            $age=[double]$entry.age_s
            if([double]::IsNaN($age) -or [double]::IsInfinity($age) -or $age -lt 0 -or $age -gt 1.5){return $null}
        }
        return $f
    }catch{return $null}
}
$script:jesterMissileCache=@{}
$script:jesterProcessedPacket=[datetime]::MinValue
function Draw-JesterMissiles {
    $missileCanvas.Children.Clear()
    $now=[datetime]::UtcNow
    $feed=Get-ActiveMissileFeed
    $f=$feed.Packet
    if($script:missileSelectedSource -ne $feed.Source){$script:jesterMissileCache=@{};$script:jesterProcessedPacket=[datetime]::MinValue;$script:missileSelectedSource=$feed.Source}
    $cameraFresh=($now-$script:dlLast).TotalSeconds -le 1 -and $null -ne $script:dlFrame -and (Test-JesterVector $script:dlFrame.ownship)
    if($cameraFresh -and $null -ne $f -and $feed.Last -ne $script:jesterProcessedPacket -and ($now-$feed.Last).TotalSeconds -le 1.5){
        $script:jesterProcessedPacket=$feed.Last
        foreach($entry in @($script:jesterMissileCache.Values)){$entry.Verified=$false}
        if($f.state -eq 'AWARENESS'){
            foreach($entry in @($f.missiles)){
                if(-not (Test-HostileMissileMarker $entry)){$script:jesterMissileCache.Remove([string]$entry.id);continue}
                if(-not $entry.id -or [double]$entry.age_s+($now-$feed.Last).TotalSeconds -gt 1.5){continue}
                $own=$script:dlFrame.ownship
                if($null -ne $entry.world){$world=$entry.world}
                else{$r=$entry.ned;$world=@{x=$own.x+$r.x;y=$own.y-$r.z;z=$own.z+$r.y}}
                $distance=0.0;foreach($axis in @('x','y','z')){$d=$world.$axis-$own.$axis;$distance+=$d*$d}
                if($distance -gt $script:alertRangeM*$script:alertRangeM){continue}
                $script:jesterMissileCache[[string]$entry.id]=[pscustomobject]@{
                    Identity=$entry.identity;OwnLaunch=$entry.own_launch;Type=$entry.type;World=$world;Seen=$feed.Last.AddSeconds(-[double]$entry.age_s);Verified=$true
                }
            }
        }
    }
    $count=0;$lost=0
    foreach($id in @($script:jesterMissileCache.Keys)){
        $entry=$script:jesterMissileCache[$id]
        if(-not (Test-HostileMissileMarker @{identity=$entry.Identity;own_launch=$entry.OwnLaunch})){$script:jesterMissileCache.Remove($id);continue}
        $age=($now-$entry.Seen).TotalSeconds
        if($age -gt 3){$script:jesterMissileCache.Remove($id);continue}
        if(-not $cameraFresh){continue}
        $own=$script:dlFrame.ownship;$world=$entry.World
        $d2=0.0;foreach($axis in @('x','y','z')){$delta=$world.$axis-$own.$axis;$d2+=$delta*$delta}
        if($d2 -gt $script:alertRangeM*$script:alertRangeM){continue}
        $cue=Get-JesterMissileCue $script:dlFrame.camera $world
        if($null -eq $cue){continue}
        $uncertain=-not $entry.Verified -or $age -gt 1.5 -or ($now-$feed.Last).TotalSeconds -gt 1.5
        $size=$script:missileSize
        $glyph=New-Object Windows.Controls.Canvas
        $incoming=-not $uncertain -and (Test-MissileMarkerInbound $id)
        $triangle=New-HornetMissileShape $incoming $size
        [void]$glyph.Children.Add($triangle)
        $label=New-Object Windows.Controls.TextBlock
        $label.Text=Get-ShortMissileName $entry.Type;$label.Foreground='#FF5050';$label.FontFamily=$script:instrumentFont;$label.FontSize=20*$size
        [Windows.Controls.Canvas]::SetLeft($label,22*$size);[Windows.Controls.Canvas]::SetTop($label,-12*$size)
        [void]$glyph.Children.Add($label)
        if($uncertain){$glyph.Opacity=0.5;$lost++}
        [Windows.Controls.Canvas]::SetLeft($glyph,$cue.X);[Windows.Controls.Canvas]::SetTop($glyph,$cue.Y)
        Set-HudAspectTransform $glyph
        [void]$missileCanvas.Children.Add($glyph)
        $count++
    }
    $missileStatus.Text=if(-not $cameraFresh){('MISSILES '+$feed.Source+' / NO CAMERA')}else{('MISSILES {0} / {1} / LOST {2} / {3:0} NM' -f $feed.Source,$count,$lost,($script:alertRangeM/1852.0))}
}
