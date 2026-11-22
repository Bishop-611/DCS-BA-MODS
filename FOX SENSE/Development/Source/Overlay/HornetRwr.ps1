$script:rwrContacts=$null
$script:rwrContactsLast=[datetime]::MinValue
function ConvertFrom-RwrContactsLine([string]$Line){
    $prefix='F4RWR_CONTACTS_V1|';$i=$Line.IndexOf($prefix)
    if($i -lt 0 -or $Line.Length -gt 65536){return $null}
    try{
        $f=$Line.Substring($i+$prefix.Length)|ConvertFrom-Json
        if($f.state -notin @('LIVE','TEST','UNAVAILABLE') -or @($f.contacts).Count -gt 64){return $null}
        foreach($c in @($f.contacts)){if($null -eq $c.hour -or [double]$c.hour -lt 0 -or [double]$c.hour -gt 12){return $null}}
        return $f
    }catch{return $null}
}
function Get-HornetThreatCode($Contact){
    # Original display symbols are independent of Jester voice phrases.
    $native=@{two='2';two_bar='2';three='3';four='4';five='5';six='6';seven='7';eight='8';nine='9';ten='10';eleven='11';fifteen='15';nineteen='19';h='H';r='R';p_bar='P';search='S';uncorrelated_missile_launch='M'}
    $symbols=@([string]$Contact.symbol1,[string]$Contact.symbol2)
    $codes=@($symbols|ForEach-Object {$name=$_.ToLowerInvariant();if($native.ContainsKey($name)){$native[$name]}}|Select-Object -Unique)
    if($codes.Count -gt 1){return ($codes -join '/')}
    if($codes.Count -eq 1){return $codes[0]}

    $name=([string]$Contact.type1+' '+[string]$Contact.type2).ToLowerInvariant()
    if($name -match '(?:^|[^a-z0-9])sa[- _]?(\d{1,2})(?:[^0-9]|$)'){return $Matches[1]}
    if($name -match '(?:mig|su|f)[- _]?(\d{1,2})(?:[^0-9]|$)'){return $Matches[1]}
    if($name -match 'patriot'){return 'P'}
    if($name -match 'hawk'){return 'H'}
    if($name -match 'awacs|e-?3'){return 'E3'}
    if($symbols -contains 'ai_group_1'){return 'EW'}
    if(@($symbols|Where-Object {$_ -match '^ai_group_[234]$'}).Count -gt 0 -or $Contact.category -eq 'airborne'){return 'AI'}
    return 'U'
}
function Draw-HornetRwrSymbol($Cue,[string]$Code,[string]$Activity){
    $scale=$script:rwrSize
    $glyph=New-Object Windows.Controls.Canvas
    $glyph.Width=80;$glyph.Height=80
    # Bare emitter code with a short stem towards helmet center.
    $outline=New-Object Windows.Shapes.Polyline
    $dx=1280-$Cue.X;$dy=720-$Cue.Y;$length=[Math]::Sqrt($dx*$dx+$dy*$dy)
    if($length -lt 1){$dx=0;$dy=1;$length=1}
    $points=New-Object Windows.Media.PointCollection
    $points.Add([Windows.Point]::new(40+20*$dx/$length,40+20*$dy/$length))
    $points.Add([Windows.Point]::new(40+44*$dx/$length,40+44*$dy/$length))
    $outline.Points=$points
    $outline.Stroke='#83FF9B';$outline.StrokeThickness=1.5
    $outline.RenderTransform=[Windows.Media.ScaleTransform]::new($scale,$scale,40,40)
    [void]$glyph.Children.Add($outline)
    $text=New-Object Windows.Controls.TextBlock
    $text.Text=$Code;$text.Width=80;$text.TextAlignment='Center';$text.FontFamily=$script:instrumentFont;$text.FontSize=28*$script:rwrSize;$text.Foreground='#83FF9B'
    [Windows.Controls.Canvas]::SetTop($text,(40-18*$script:rwrSize));[void]$glyph.Children.Add($text)
    if($Activity -in @('track','lock','launch')){
        $arc=New-Object Windows.Shapes.Polyline;$points=New-Object Windows.Media.PointCollection
        foreach($degree in 0..18){$rad=$degree*[Math]::PI/18;$points.Add([Windows.Point]::new(40+29*$scale*[Math]::Cos($rad),40+29*$scale*[Math]::Sin($rad)))}
        $arc.Points=$points;$arc.Stroke='#83FF9B';$arc.StrokeThickness=1.5;[void]$glyph.Children.Add($arc)
    }
    if($Cue.Edge -ne 0){
        $arrow=New-Object Windows.Controls.TextBlock;$arrow.Text=if($Cue.Edge -lt 0){'<'}else{'>'};$arrow.FontSize=28*$script:rwrSize;$arrow.Foreground='#83FF9B'
        [Windows.Controls.Canvas]::SetLeft($arrow,($(if($Cue.Edge -lt 0){-12}else{75})));[Windows.Controls.Canvas]::SetTop($arrow,25);[void]$glyph.Children.Add($arrow)
    }
    if($Activity -eq 'launch'){$glyph.Opacity=if($script:flash){1}else{0.25}}
    [Windows.Controls.Canvas]::SetLeft($glyph,($Cue.X-40));[Windows.Controls.Canvas]::SetTop($glyph,($Cue.Y-40))
    Set-HudAspectTransform $glyph 40 40
    [void]$rwrCueCanvas.Children.Add($glyph)
}
function Get-ActiveRwrFrame {
    $now=[datetime]::UtcNow
    $jester=$null;$native=$null
    if($null -ne $script:rwrContacts -and ($now-$script:rwrContactsLast).TotalSeconds -le 2){
        if($script:rwrContacts.state -eq 'TEST'){$jester=[pscustomobject]@{state='TEST';source='JESTER';contacts=@()}}
        if($script:rwrContacts.state -eq 'LIVE'){$jester=[pscustomobject]@{state='LIVE';source='JESTER';contacts=@($script:rwrContacts.contacts)}}
    }elseif($null -ne $script:receiverEvent -and ($now-$script:lastEvent).TotalSeconds -le 8){
        $e=$script:receiverEvent
        if($e.Mode -eq 'TEST'){$jester=[pscustomobject]@{state='TEST';source='JESTER';contacts=@()}}
        if($e.Mode -in @('CONTACT','LAUNCH')){
            $jester=[pscustomobject]@{state='LIVE';source='JESTER VOICE';contacts=@([pscustomobject]@{hour=$e.Hour;activity=$(if($e.Mode -eq 'LAUNCH'){'launch'}else{$e.Activity});type1='';type2=''})}
        }elseif($e.Mode -eq 'CLEAR'){$jester=[pscustomobject]@{state='LIVE';source='JESTER VOICE';contacts=@()}}
    }
    if($script:modernRwrEnabled -and $null -ne $script:nativeRwr -and ($now-$script:nativeRwrLast).TotalSeconds -le 2){
        $native=[pscustomobject]@{state=$script:nativeRwr.state;source='NATIVE';contacts=@($script:nativeRwr.contacts)}
        if($native.state -eq 'LIVE' -and $native.contacts.Count -gt 0){return (Limit-RwrFrame $native)}
    }
    if($script:modernRwrEnabled){$mission=Get-MissionRwrFrame;if($null -ne $mission -and $mission.contacts.Count -gt 0){return (Limit-RwrFrame $mission)}}
    if($null -ne $jester){return (Limit-RwrFrame $jester)}
    if($null -ne $native){return (Limit-RwrFrame $native)}
    return [pscustomobject]@{state='UNAVAILABLE';source='RWR';contacts=@()}
}
function Draw-RwrCue {
    $rwrCueCanvas.Children.Clear()
    if(([datetime]::UtcNow-$script:dlLast).TotalSeconds -gt 1 -or $null -eq $script:dlFrame){return}
    $f=$script:dlFrame;$fov=if($null -ne $fovSlider){$fovSlider.Value}else{90}
    $receiver=Get-ActiveRwrFrame
    if($receiver.state -ne 'LIVE'){return}
    if($receiver.source -eq 'NATIVE' -and $receiver.contacts.Count -gt 0){
        $status.Text='NATIVE RWR / JHMCS';$status.Foreground=[Windows.Media.Brushes]::LightGreen
        $detail.Text='Enhanced sensor / experimental bearing / receiver reports only'
    }
    foreach($c in @($receiver.contacts)){
        $cue=Get-RwrAzimuthCue $f.camera $f.own_heading ([double]$c.hour) $fov $script:rwrProjectionZoom
        if($null -eq $cue){continue}
        $code=if($c.native_code){$c.native_code}else{Get-HornetThreatCode $c}
        Draw-HornetRwrSymbol $cue $code ([string]$c.activity)
    }
}
