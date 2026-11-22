function New-SaMissileLayer($Frame){
    $layer=New-Object Windows.Controls.Canvas;$layer.Tag='SaMissileLayer'
    $feed=Get-ActiveMissileFeed;$script:saMissileSource=$feed.Source
    if($null -eq $feed.Packet -or ([datetime]::UtcNow-$feed.Last).TotalSeconds -gt 1.5 -or -not (Test-JesterVector $Frame.ownship)){return $layer}
    foreach($entry in @($feed.Packet.missiles)){
        if(-not (Test-HostileMissileMarker $entry)){continue}
        if([double]$entry.age_s+([datetime]::UtcNow-$feed.Last).TotalSeconds -gt 1.5){continue}
        if($null -ne $entry.world){$p=$entry.world}
        else{if(-not (Test-JesterVector $entry.ned)){continue};$r=$entry.ned;$p=@{x=$Frame.ownship.x+$r.x;y=$Frame.ownship.y-$r.z;z=$Frame.ownship.z+$r.y}}
        $distance=0.0;foreach($axis in @('x','y','z')){$d=$p.$axis-$Frame.ownship.$axis;$distance+=$d*$d}
        if($distance -gt $script:alertRangeM*$script:alertRangeM){continue}
        # The map function uses identity only as a validity filter; geometry is identical.
        $point=Get-DatalinkMapPoint $Frame ([pscustomobject]@{identity='HOSTILE';p=$p})
        if($null -eq $point){continue}
        $glyph=New-Object Windows.Controls.Canvas;$glyph.Tag='SaMissileContact'
        $triangle=New-HornetMissileShape (Test-MissileMarkerInbound ([string]$entry.id)) 0.55;[void]$glyph.Children.Add($triangle)
        $label=New-Object Windows.Controls.TextBlock;$label.Text=Get-ShortMissileName $entry.type;$label.FontSize=10;$label.Foreground='#FF5050'
        [Windows.Controls.Canvas]::SetLeft($label,10);[Windows.Controls.Canvas]::SetTop($label,-6);[void]$glyph.Children.Add($label)
        [Windows.Controls.Canvas]::SetLeft($glyph,$point.X);[Windows.Controls.Canvas]::SetTop($glyph,$point.Y);[void]$layer.Children.Add($glyph)
    }
    return $layer
}
