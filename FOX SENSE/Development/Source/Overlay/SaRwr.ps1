$script:saRwrEnabled=$true
function Get-SaRwrPoint($Contact){
    if($null -eq $Contact.hour){return $null}
    try{$hour=[double]$Contact.hour}catch{return $null}
    if([double]::IsNaN($hour) -or [double]::IsInfinity($hour) -or $hour -le 0 -or $hour -gt 12){return $null}
    # Fixed body-relative bearing ring, unrelated to selected aircraft range.
    $angle=$hour*[Math]::PI/6
    return [pscustomobject]@{X=210+139*[Math]::Sin($angle);Y=210-139*[Math]::Cos($angle)}
}
function New-SaRwrLayer {
    $layer=New-Object Windows.Controls.Canvas;$layer.Tag='RwrBearingLayer'
    $receiver=Get-ActiveRwrFrame
    $message=switch($receiver.state){
        TEST {'RWR: TEST / ALERTS SUPPRESSED'}
        BLOCKED {'RWR: EXPORT BLOCKED'}
        LIVE {if($receiver.contacts.Count -eq 0){'RWR: NO REPORTED CONTACTS'}else{$receiver.source+' RWR / BRG ONLY'}}
        default {'RWR: NO DATA'}
    }
    $unknown=0
    if($receiver.state -eq 'LIVE'){
        foreach($contact in @($receiver.contacts)){
            $point=Get-SaRwrPoint $contact
            if($null -eq $point){$unknown++;continue}
            $glyph=New-Object Windows.Controls.Canvas;$glyph.Tag='SaRwrContact'
            $glyph.Width=32;$glyph.Height=32
            $activity=([string]$contact.activity).ToLowerInvariant()
            $color=if($activity -eq 'launch'){'#FF7878'}elseif($activity -in @('lock','track')){'#FFCF70'}else{'#83FF9B'}
            $outline=New-Object Windows.Shapes.Polyline
            $outline.Points=[Windows.Media.PointCollection]::Parse('1,1 31,1 31,23 16,31 1,23 1,1')
            $outline.Stroke=$color;$outline.StrokeThickness=1.4;[void]$glyph.Children.Add($outline)
            $text=New-Object Windows.Controls.TextBlock
            $text.Text=if($contact.native_code){$contact.native_code}else{Get-HornetThreatCode $contact}
            $text.Width=32;$text.TextAlignment='Center';$text.Foreground=$color;$text.FontSize=14
            [Windows.Controls.Canvas]::SetTop($text,4);[void]$glyph.Children.Add($text)
            if($activity -in @('lock','track','launch')){
                $circle=New-Object Windows.Shapes.Ellipse;$circle.Width=40;$circle.Height=40
                $circle.Stroke=$color;$circle.StrokeThickness=1.4
                [Windows.Controls.Canvas]::SetLeft($circle,-4);[Windows.Controls.Canvas]::SetTop($circle,-4);[void]$glyph.Children.Add($circle)
            }
            if($activity -eq 'launch'){$glyph.Opacity=if($script:flash){1}else{0.3}}
            [Windows.Controls.Canvas]::SetLeft($glyph,($point.X-16));[Windows.Controls.Canvas]::SetTop($glyph,($point.Y-16))
            [void]$layer.Children.Add($glyph)
        }
    }
    if($unknown){$message+=' / '+$unknown+' BRG UNKNOWN'}
    $label=New-Object Windows.Controls.TextBlock;$label.Text=$message;$label.FontSize=11;$label.Tag='SaRwrStatus';$label.Visibility='Collapsed'
    [Windows.Controls.Canvas]::SetLeft($label,18);[Windows.Controls.Canvas]::SetTop($label,386);[void]$layer.Children.Add($label)
    return $layer
}
