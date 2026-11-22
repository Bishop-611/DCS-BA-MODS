param([switch]$Demo,[string]$RenderPreview,[switch]$SelfTest,[string]$ProfileRoot,[switch]$ModernPreview,[switch]$RuntimeControlsTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -Path (Join-Path $PSScriptRoot 'Fox.Runtime.dll')
. (Join-Path $PSScriptRoot 'InstrumentFont.ps1')
. (Join-Path $PSScriptRoot 'Protocol.ps1')
. (Join-Path $PSScriptRoot 'AspectLayout.ps1')
. (Join-Path $PSScriptRoot 'ViewProjection.ps1')
. (Join-Path $PSScriptRoot 'Datalink.ps1')
. (Join-Path $PSScriptRoot 'RangeHighlights.ps1')
. (Join-Path $PSScriptRoot 'JesterMissiles.ps1')
. (Join-Path $PSScriptRoot 'RangeAndView.ps1')
. (Join-Path $PSScriptRoot 'MissileSources.ps1')
. (Join-Path $PSScriptRoot 'MissileAudio.ps1')
. (Join-Path $PSScriptRoot 'RadarLockAudio.ps1')
. (Join-Path $PSScriptRoot 'WarningLoops.ps1')
. (Join-Path $PSScriptRoot 'IncomingMissiles.ps1')
. (Join-Path $PSScriptRoot 'HornetStyle.ps1')
. (Join-Path $PSScriptRoot 'HornetRwr.ps1')
. (Join-Path $PSScriptRoot 'ModernRwr.ps1')
. (Join-Path $PSScriptRoot 'SaRwr.ps1')
. (Join-Path $PSScriptRoot 'SaMissiles.ps1')
. (Join-Path $PSScriptRoot 'DatalinkOverlay.ps1')
. (Join-Path $PSScriptRoot 'Settings.ps1')
. (Join-Path $PSScriptRoot 'MenuAudio.ps1')
. (Join-Path $PSScriptRoot 'AudioVolume.ps1')
. (Join-Path $PSScriptRoot 'ControlsFocus.ps1')
. (Join-Path $PSScriptRoot 'MenuLifecycle.ps1')
. (Join-Path $PSScriptRoot 'OverlayVisibility.ps1')
. (Join-Path $PSScriptRoot 'FloatingMenu.ps1')
$script:settingsReady=$false
$settingsPath=Join-Path (Split-Path $PSScriptRoot) 'HudSettings.json'
function Load-Xaml([string]$Name) {
    $text=Get-Content -LiteralPath (Join-Path $PSScriptRoot $Name) -Raw
    if($Name -eq 'Hud.xaml'){$text=ConvertTo-InstrumentXaml $text}
    [xml]$xml=$text
    $window=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xml))
    if($Name -eq 'Hud.xaml'){$window.FontFamily=$script:instrumentFont}
    if($Name -eq 'Controls.xaml'){$window.FindName('MenuBackground').Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $PSScriptRoot 'Art\menu-background.png'))}
    return $window
}
$hudWindow=Load-Xaml 'Hud.xaml'
$hud=$hudWindow.FindName('Hud')
$status=$hudWindow.FindName('Status')
$detail=$hudWindow.FindName('Detail')
$source=$hudWindow.FindName('Source')
$threat=$hudWindow.FindName('Threat')
$sector=$hudWindow.FindName('Sector')
$sectorStart=$hudWindow.FindName('SectorStart')
$sectorEnd=$hudWindow.FindName('SectorEnd')
$bearingLabel=$hudWindow.FindName('BearingLabel')
$audioLabel=$hudWindow.FindName('AudioLabel')
$trackCanvas=$hudWindow.FindName('TrackLayer')
$rwrCueCanvas=$hudWindow.FindName('RwrCueLayer')
$datalinkOverlayCanvas=$hudWindow.FindName('DatalinkOverlayLayer')
$missileCanvas=$hudWindow.FindName('MissileLayer')
$missileStatus=$hudWindow.FindName('MissileStatus')
$dlStatus=$hudWindow.FindName('DatalinkStatus')
foreach($instrument in $hudWindow.FindName('FlightData').Children){
    Set-HudAspectTransform $instrument (1280-[Windows.Controls.Canvas]::GetLeft($instrument)) (720-[Windows.Controls.Canvas]::GetTop($instrument))
}
Set-HudAspectTransform $dlStatus 400 0
Set-HudAspectTransform $missileStatus
$script:readers=@()
$script:reader=$null
$script:lastEvent=[datetime]::MinValue
$script:lastBeep=[datetime]::MinValue
$script:lastMode=''
$script:telemetryLast=[datetime]::MinValue
$script:partial=''
$script:demoStep=0
$script:flash=$false
# Store original text sizes once so repeated slider updates never compound.
$script:fontBaselines=@{}
function Register-HudText($panel){
    foreach($child in $panel.Children){
        if($child -is [Windows.Controls.TextBlock]){$script:fontBaselines[$child]=$child.FontSize}
        elseif($child -is [Windows.Controls.Panel]){Register-HudText $child}
        elseif($child -is [Windows.Controls.Border] -and $child.Child -is [Windows.Controls.Panel]){Register-HudText $child.Child}
    }
}
Register-HudText $hud
function Set-HudFontScale([double]$Factor){
    $factor=[Math]::Max(0.6,[Math]::Min(2.5,$Factor));$script:fontFactor=$factor
    foreach($item in $script:fontBaselines.Keys){$item.FontSize=$script:fontBaselines[$item]*$factor}
}
function Reset-HudOffsets($Horizontal,$Vertical){
    $Horizontal.Value=0
    $Vertical.Value=0
}
function Set-ClockSector([int]$Hour) {
    if($Hour -lt 1 -or $Hour -gt 12){$threat.Visibility='Hidden';return}
    $points=New-Object Windows.Media.PointCollection
    $angle=$Hour*30
    for($step=0;$step -le 16;$step++){
        $radians=($angle-15+$step*30/16)*[Math]::PI/180
        $points.Add([Windows.Point]::new((2200+90*[Math]::Sin($radians)),(1000-90*[Math]::Cos($radians))))
    }
    $sector.Points=$points
    foreach($boundary in @(@($sectorStart,($angle-15)),@($sectorEnd,($angle+15)))){
        $rad=$boundary[1]*[Math]::PI/180
        $line=$boundary[0]
        $line.X1=2200+82*[Math]::Sin($rad);$line.Y1=1000-82*[Math]::Cos($rad)
        $line.X2=2200+98*[Math]::Sin($rad);$line.Y2=1000-98*[Math]::Cos($rad)
    }
    $rad=$angle*[Math]::PI/180
    [Windows.Controls.Canvas]::SetLeft($bearingLabel,(2200+120*[Math]::Sin($rad)-20))
    [Windows.Controls.Canvas]::SetTop($bearingLabel,(1000-120*[Math]::Cos($rad)-9))
    $bearingLabel.Text=('{0:00} H' -f $Hour)
    $threat.Visibility='Visible'
}
function Show-ReceiverEvent($e) {
    $script:receiverEvent=$e
    $script:lastEvent=[datetime]::UtcNow
    $source.Text=if($Demo -or $RenderPreview){'DEMO / SYNTHETIC DATA'}else{'JESTER RWR / LIVE RECEIVER'}
    $color=[Windows.Media.Brushes]::LightGreen
    switch($e.Mode){
        LAUNCH {$status.Text='LAUNCH';$color=[Windows.Media.Brushes]::OrangeRed}
        CONTACT {$status.Text='RADAR CONTACT';$color=[Windows.Media.Brushes]::LightGreen}
        CLEAR {$status.Text='NO REPORTED RWR CONTACTS'}
        TEST {$status.Text='RWR TEST / ALERTS SUPPRESSED';$color=[Windows.Media.Brushes]::LightBlue}
        default {$status.Text='RWR DATA UNAVAILABLE';$color=[Windows.Media.Brushes]::Gray}
    }
    $status.Opacity=1
    $status.Foreground=$color
    $sector.Stroke=$color;$sectorStart.Stroke=$color;$sectorEnd.Stroke=$color;$bearingLabel.Foreground=$color
    $threat.Opacity=1
    if($e.Mode -in @('CONTACT','LAUNCH')){
        Set-ClockSector $e.Hour
        $bearing=if($e.Hour){"$($e.Hour) O'CLOCK"}else{'BEARING UNKNOWN'}
        $detail.Text="BODY: $bearing | $($e.Category) | $($e.Activity)"
    }else{
        $threat.Visibility='Hidden'
        $detail.Text='Receiver reports only; no contacts does not mean safe.'
    }
    $now=[datetime]::UtcNow
    $script:lastMode=$e.Mode
}
function Set-NoSignal([string]$Title,[string]$Description){
    $status.Text=$Title;$status.Foreground=[Windows.Media.Brushes]::Gray
    $source.Text='NO LIVE RECEIVER SIGNAL';$detail.Text=$Description
    $threat.Visibility='Hidden';$script:lastMode=''
$script:telemetryLast=[datetime]::MinValue
}
if($SelfTest){
    # Legacy projection fixtures exercise geometry independently of identity filtering.
    $script:hostileMissileMarkersOnly=$false
    foreach($hour in 1..12){
        Show-ReceiverEvent ([pscustomobject]@{Mode='CONTACT';Hour=$hour;Activity='observed';Category='surface'})
        if($threat.Visibility -ne 'Visible' -or $sector.Points.Count -ne 17){throw 'Sector generation failed'}
        foreach($point in $sector.Points){
            if($point.X -lt 2109 -or $point.X -gt 2291 -or $point.Y -lt 909 -or $point.Y -gt 1091){throw 'Sector outside HUD'}
        }
    }
    Show-ReceiverEvent ([pscustomobject]@{Mode='LAUNCH';Hour=3;Activity='launch';Category='surface'})
    if($status.Text -ne 'LAUNCH' -or $threat.Visibility -ne 'Visible'){throw 'Launch UI failed'}
    Show-ReceiverEvent ([pscustomobject]@{Mode='CONTACT';Hour=0;Activity='unknown';Category='unknown'})
    if($threat.Visibility -ne 'Hidden'){throw 'Unknown bearing must hide sector'}
    foreach($mode in @('CLEAR','TEST','UNAVAILABLE')){
        Show-ReceiverEvent ([pscustomobject]@{Mode=$mode;Hour=2;Activity='';Category=''})
        if($threat.Visibility -ne 'Hidden'){throw 'Stale sector in noncontact state'}
    }
    Set-NoSignal 'NO LIVE RWR DATA' 'timeout test'
    if($threat.Visibility -ne 'Hidden' -or $script:lastMode -ne ''){throw 'Timeout must clear threat'}
    $testControls=Load-Xaml 'Controls.xaml'
    foreach($name in @('Audio','Size','FontScale','FontValue','Opacity','OffsetX','OffsetY','ResetPosition','HideControls','HorizontalFov','MarkerScale')){
        if($null -eq $testControls.FindName($name)){throw ('Missing control '+$name)}
    }
    foreach($factor in @(0.6,1.0,1.5,2.5,1.0)){
        Set-HudFontScale $factor
        foreach($item in $script:fontBaselines.Keys){
            $expected=$script:fontBaselines[$item]*$factor
            if([Math]::Abs($item.FontSize-$expected) -gt 0.001){throw 'Font scaling drift or missing text'}
        }
    }
    $testX=$testControls.FindName('OffsetX');$testY=$testControls.FindName('OffsetY')
    $testX.Value=150;$testY.Value=-100
    $testControls.FindName('FontScale').Value=1.7
    $testControls.FindName('Size').Value=1.2
    $testControls.FindName('Opacity').Value=0.65
    Reset-HudOffsets $testX $testY
    if($testX.Value -ne 0 -or $testY.Value -ne 0){throw 'Position reset failed'}
    if($testControls.FindName('FontScale').Value -ne 1.7 -or $testControls.FindName('Size').Value -ne 1.2 -or $testControls.FindName('Opacity').Value -ne 0.65){throw 'Position reset changed unrelated settings'}
    Write-Output 'PASS: font scaling 60-250%, repeated scaling without drift; position reset preserves font/size/opacity'
    $camera=[pscustomobject]@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};up=@{x=0;y=1;z=0};right=@{x=0;y=0;z=1}}
    $point=Get-TrackProjection $camera @{x=1000;y=0;z=0} 90
    if([Math]::Abs($point.X-1280) -gt 0.01 -or [Math]::Abs($point.Y-720) -gt 0.01){throw 'Forward projection incorrect'}
    if((Get-TrackProjection $camera @{x=1000;y=0;z=100} 90).X -le 1280){throw 'Right projection incorrect'}
    if((Get-TrackProjection $camera @{x=1000;y=100;z=0} 90).Y -ge 720){throw 'Up projection incorrect'}
    if($null -ne (Get-TrackProjection $camera @{x=-1000;y=0;z=0} 90)){throw 'Behind-camera target drawn'}
    $rotated=[pscustomobject]@{p=@{x=0;y=0;z=0};forward=@{x=0;y=0;z=1};up=@{x=0;y=1;z=0};right=@{x=-1;y=0;z=0}}
    $point=Get-TrackProjection $rotated @{x=0;y=0;z=1000} 90
    if([Math]::Abs($point.X-1280) -gt 0.01){throw 'Head rotation projection incorrect'}
    $frame=New-DatalinkDemo 0
    $wire='F4DL_V1|'+($frame|ConvertTo-Json -Depth 8 -Compress)
    if($null -eq (ConvertFrom-DatalinkLine $wire)){throw 'Datalink parser rejected valid frame'}
    if($null -ne (ConvertFrom-DatalinkLine 'F4DL_V1|{}')){throw 'Datalink parser accepted invalid frame'}
    Set-DatalinkFrame $frame $true;Draw-Datalink
    if($trackCanvas.Children.Count -ne 2){throw 'Only friendly and hostile symbols expected; no labels or unknown markers'}
    $script:dlLast=[datetime]::UtcNow.AddSeconds(-5);Draw-Datalink
    if($trackCanvas.Children.Count -ne 0){throw 'Stale datalink symbols retained'}
    Write-Output 'PASS: track parser, forward/right/up and head rotation projection, behind-view suppression, two markers without labels, stale-feed clearing'
    Set-DatalinkFrame (New-DatalinkDemo 0) $true
    $fixedX=$null;$fixedY=$null
    foreach($scale in @(0.6,1.0,1.8)){
        $script:aircraftSize=$scale;Draw-Datalink
        $circle=$trackCanvas.Children[0]
        $centerX=[Windows.Controls.Canvas]::GetLeft($circle)+$circle.Width/2
        $centerY=[Windows.Controls.Canvas]::GetTop($circle)+$circle.Height/2
        if($null -eq $fixedX){$fixedX=$centerX;$fixedY=$centerY}
        if([Math]::Abs($centerX-$fixedX) -gt 0.001 -or [Math]::Abs($centerY-$fixedY) -gt 0.001){throw 'HUD size moved spatial marker center'}
    }
    $script:contentScale=1;$script:aircraftSize=1
    Write-Output 'PASS: 60%, 100%, 180% symbol scaling leaves projected center unchanged'
    $script:projectionScaleX=1.25;$script:projectionScaleY=0.75
    $script:markerOffsetX=30;$script:markerOffsetY=-20
    $calibrated=Get-TrackProjection $camera @{x=1000;y=100;z=100} 90
    if([Math]::Abs($calibrated.X-1470) -gt 0.01 -or [Math]::Abs($calibrated.Y-604) -gt 0.01){throw 'Manual calibration incorrect'}
    $script:projectionScaleX=1;$script:projectionScaleY=1;$script:markerOffsetX=0;$script:markerOffsetY=0
    $rangeFrame=[pscustomobject]@{state='LIVE_POSITIONS';camera=$camera;ownship=@{x=0;y=0;z=0};tracks=@(
      @{identity='FRIENDLY';age_s=0;p=@{x=37040;y=0;z=0}},
      @{identity='HOSTILE';age_s=0;p=@{x=37041;y=0;z=0}})}
    Set-DatalinkFrame $rangeFrame;Draw-Datalink
    if($trackCanvas.Children.Count -ne 1){throw '20 NM inclusive range filter failed'}
    $datalinkCheckbox=$testControls.FindName('DatalinkEnabled')
    if($datalinkCheckbox.IsChecked){throw 'Datalink should default off'}
    Draw-Datalink
    if($trackCanvas.Children.Count -ne 0){throw 'Datalink checkbox failed to hide markers'}
    $datalinkCheckbox.IsChecked=$true;Draw-Datalink
    if($trackCanvas.Children.Count -ne 1){throw 'Datalink checkbox failed to enable markers'}
    $datalinkCheckbox=$null
    Write-Output 'PASS: manual X/Y calibration, 20 NM boundary, optional datalink defaults off'
    $frontCue=Get-RwrAzimuthCue $camera 0 12
    if($null -eq $frontCue -or [Math]::Abs($frontCue.X-1280) -gt 0.01 -or $frontCue.Edge -ne 0){throw 'RWR forward cue incorrect'}
    $yawCamera=@{forward=@{x=[Math]::Cos(0.3);y=0;z=[Math]::Sin(0.3)}}
    $turnedCue=Get-RwrAzimuthCue $yawCamera 0 12
    if($turnedCue.X -ge 1280){throw 'RWR cue did not move left when looking right'}
    if((Get-RwrAzimuthCue $camera 0 3).X -le 1280 -or (Get-RwrAzimuthCue $camera 0 9).X -ge 1280){throw 'RWR right/left clock layout incorrect'}
    if((Get-RwrAzimuthCue $camera 0 12).Y -ge 720 -or (Get-RwrAzimuthCue $camera 0 6).Y -le 720){throw 'RWR fore/aft clock layout incorrect'}
    $rolled=@{forward=@{x=1;y=0;z=0};right=@{x=0;y=-1;z=0};up=@{x=0;y=0;z=1}}
    if((Get-RwrAzimuthCue $rolled 0 12).X -ge 1280){throw 'RWR roll direction incorrect'}
    if($null -ne (Get-RwrAzimuthCue $camera $null 12)){throw 'RWR heading unavailable should suppress direction'}
    $rwrFrame=[pscustomobject]@{camera=$camera;own_heading=0;tracks=@();state='NO_AIRCRAFT'}
    Set-DatalinkFrame $rwrFrame
    $datalinkCheckbox=$testControls.FindName('DatalinkEnabled');$datalinkCheckbox.IsChecked=$false
    Show-ReceiverEvent ([pscustomobject]@{Mode='CONTACT';Hour=12;Activity='none';Category='airborne'})
    Draw-RwrCue
    if($rwrCueCanvas.Children.Count -ne 1){throw 'RWR cue incorrectly tied to datalink checkbox'}
    $script:dlLast=[datetime]::UtcNow.AddSeconds(-3);Draw-RwrCue
    if($rwrCueCanvas.Children.Count -ne 0){throw 'RWR retained stale head orientation'}
    $datalinkCheckbox=$null
    Write-Output 'PASS: RWR follows head yaw/roll, helmet clock layout, absent-heading suppression, independent datalink toggle, stale-camera clearing'
    if((Get-HornetThreatCode ([pscustomobject]@{symbol1='five';symbol2='five';type1='';type2=''})) -ne '5'){throw 'Native SA-5 symbol lost when voice phrase absent'}
    if((Get-HornetThreatCode ([pscustomobject]@{symbol1='seven';symbol2='seven';type1='';type2=''})) -ne '7'){throw 'Native symbol without voice phrase lost'}
    if((Get-HornetThreatCode ([pscustomobject]@{symbol1='unknown_future';symbol2='';type1='';type2=''})) -ne 'U'){throw 'Unknown native symbol fabricated identity'}
    Write-Output 'PASS: raw display five/seven survive absent voice mapping; unknown symbols remain U'
    $settingsFixture=Join-Path (Split-Path $PSScriptRoot) 'Settings-test.json'
    $testControls.FindName('CenterZoom').Value=1.38
    $testControls.FindName('RwrZoom').Value=0.77
    $testControls.FindName('DatalinkEnabled').IsChecked=$true
    Save-HudSettings $testControls $settingsFixture
    $reopened=Load-Xaml 'Controls.xaml'
    Load-HudSettings $reopened $settingsFixture
    if([Math]::Abs($reopened.FindName('CenterZoom').Value-1.38) -gt 0.001 -or [Math]::Abs($reopened.FindName('RwrZoom').Value-0.77) -gt 0.001 -or -not $reopened.FindName('DatalinkEnabled').IsChecked){throw 'Calibration persistence failed'}
    if((Get-HornetThreatCode ([pscustomobject]@{symbol1='ai_group_2';symbol2='ai_group_2';type1='aircraft';type2='aircraft'})) -ne 'AI'){throw 'Airborne category rendered as unknown'}
    if((Get-HornetThreatCode ([pscustomobject]@{symbol1='ai_group_1';symbol2='ai_group_1';type1='aircraft';type2='aircraft'})) -ne 'EW'){throw 'Airborne early warning category incorrect'}
    Write-Output 'PASS: independent calibration round-trip to disk; airborne AI and EW classification without invented aircraft model'
    $testControls.FindName('AircraftSize').Value=0.8
    $testControls.FindName('MissileSize').Value=1.4
    $testControls.FindName('RwrSize').Value=1.9
    Save-HudSettings $testControls $settingsFixture
    $reopened=Load-Xaml 'Controls.xaml';Load-HudSettings $reopened $settingsFixture
    foreach($pair in @(@('AircraftSize',0.8),@('MissileSize',1.4),@('RwrSize',1.9))){if([Math]::Abs($reopened.FindName($pair[0]).Value-$pair[1]) -gt 0.001){throw 'Symbol group settings not restored'}}
    $rwrCueCanvas.Children.Clear();$script:rwrSize=1
    Draw-HornetRwrSymbol ([pscustomobject]@{X=800;Y=400;Edge=0}) '5' 'none'
    $first=$rwrCueCanvas.Children[0];$firstFont=$first.Children[1].FontSize
    $rwrCueCanvas.Children.Clear();$script:rwrSize=2
    Draw-HornetRwrSymbol ([pscustomobject]@{X=800;Y=400;Edge=0}) '5' 'none'
    $second=$rwrCueCanvas.Children[0]
    if($second.Children[1].FontSize -ne 2*$firstFont -or $second.Children[0].RenderTransform.ScaleX -ne 2){throw 'RWR symbol and text not linked'}
    if([Windows.Controls.Canvas]::GetLeft($first) -ne [Windows.Controls.Canvas]::GetLeft($second)){throw 'RWR size changed direction position'}
    if($script:aircraftSize -ne 1 -or $script:missileSize -ne 1){throw 'RWR scale affected another group'}
    $script:rwrSize=1
    Write-Output 'PASS: three size groups persist independently; RWR text and symbol scale together without moving bearing'
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-JesterMissiles.ps1')){. (Join-Path $PSScriptRoot 'Test-JesterMissiles.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-MissileAudio.ps1')){. (Join-Path $PSScriptRoot 'Test-MissileAudio.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-SeparateZoom.ps1')){. (Join-Path $PSScriptRoot 'Test-SeparateZoom.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-EnhancedJhmcs.ps1')){. (Join-Path $PSScriptRoot 'Test-EnhancedJhmcs.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-DatalinkRange.ps1')){. (Join-Path $PSScriptRoot 'Test-DatalinkRange.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-DatalinkOverlay.ps1')){. (Join-Path $PSScriptRoot 'Test-DatalinkOverlay.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-SaRwr.ps1')){. (Join-Path $PSScriptRoot 'Test-SaRwr.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-ControlsFocus.ps1')){. (Join-Path $PSScriptRoot 'Test-ControlsFocus.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-MissileSources.ps1')){. (Join-Path $PSScriptRoot 'Test-MissileSources.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-QuietDatalink.ps1')){. (Join-Path $PSScriptRoot 'Test-QuietDatalink.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-IncomingMissiles.ps1')){. (Join-Path $PSScriptRoot 'Test-IncomingMissiles.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-MenuAudio.ps1')){. (Join-Path $PSScriptRoot 'Test-MenuAudio.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-OverlayVisibility.ps1')){. (Join-Path $PSScriptRoot 'Test-OverlayVisibility.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-RangeAndView.ps1')){. (Join-Path $PSScriptRoot 'Test-RangeAndView.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-MenuLifecycle.ps1')){. (Join-Path $PSScriptRoot 'Test-MenuLifecycle.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-SaAircraftTypes.ps1')){. (Join-Path $PSScriptRoot 'Test-SaAircraftTypes.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-MissilePolicies.ps1')){. (Join-Path $PSScriptRoot 'Test-MissilePolicies.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-RadarLockAudio.ps1')){. (Join-Path $PSScriptRoot 'Test-RadarLockAudio.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-HornetStyle.ps1')){. (Join-Path $PSScriptRoot 'Test-HornetStyle.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-InstrumentFont.ps1')){. (Join-Path $PSScriptRoot 'Test-InstrumentFont.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-FlightDataScale.ps1')){. (Join-Path $PSScriptRoot 'Test-FlightDataScale.ps1')}
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-LowAltitudeAlpha.ps1')){. (Join-Path $PSScriptRoot 'Test-LowAltitudeAlpha.ps1')}
    . (Join-Path $PSScriptRoot 'Test-ViewProjection.ps1')
    . (Join-Path $PSScriptRoot 'Test-CameraStream.ps1')
    . (Join-Path $PSScriptRoot 'Test-AspectLayout.ps1')
    Write-Output 'PASS: all 12 clock sectors, launch, unknown bearing, clear/test/unavailable, timeout clearing, control XAML'
    exit
}
if($RenderPreview){
    Show-ReceiverEvent ([pscustomobject]@{Mode='LAUNCH';Hour=2;Activity='launch';Category='surface'})
    # Render our own WPF canvas without opening a window or reading any game log.
    Set-DatalinkFrame (New-DatalinkDemo 0) $true;Draw-Datalink
    if($ModernPreview){
        $script:dlFrame|Add-Member NoteProperty flight @{ias=177.49;altitude=1908.048;aoa=3.1;mach=0.58;g=1} -Force
        $script:dlFrame.own_heading=[Math]::PI*1.5
        $script:dlFrame.tracks[0].aircraft_type='F-15C'
        $script:dlFrame.tracks[1].aircraft_type='F-16C_50'
        Update-HornetFlightData;Draw-Datalink
        $script:modernRwrEnabled=$false
        $script:jesterMissileFrame=[pscustomobject]@{state='AWARENESS';missiles=@(
            @{id='preview-detected';identity='HOSTILE';type='SA10_5V55R';age_s=0;world=@{x=10000;y=4000;z=4000}},
            @{id='preview-inbound';identity='HOSTILE';type='AIM_120C';age_s=0;world=@{x=10000;y=7300;z=-4000}})}
        $script:jesterMissileLast=[datetime]::UtcNow
        $script:incomingSamples=@{'preview-inbound'=@{Incoming=$true}}
        $script:incomingMarkerLast=[datetime]::UtcNow
        Draw-JesterMissiles
        $script:modernRwrEnabled=$true;$script:rwrSize=1
        $script:rwrContacts=[pscustomobject]@{state='LIVE';contacts=@(
            [pscustomobject]@{hour=12;activity='search';symbol1='five'},
            [pscustomobject]@{hour=3;activity='lock';symbol1='seven'},
            [pscustomobject]@{hour=8;activity='launch';symbol1='ten'})}
        $script:rwrContactsLast=[datetime]::UtcNow;$script:flash=$true;Draw-RwrCue
        $script:datalinkOverlayEnabled=$true;Draw-DatalinkOverlay
        $detail.Text='DEMO / SYNTHETIC CONTACTS / JHMCS + OPTIONAL DATALINK'
    }
    $hud.Background=[Windows.Media.Brushes]::Black
    $hud.Measure([Windows.Size]::new(2560,1440))
    $hud.Arrange([Windows.Rect]::new(0,0,2560,1440));$hud.UpdateLayout()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(2560,1440,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($hud)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $output=[IO.File]::Create($RenderPreview)
    try{$encoder.Save($output)}finally{$output.Dispose()}
    exit
}
$controls=Load-Xaml 'Controls.xaml'
$audio=$controls.FindName('Audio')
$incomingAudioCheckbox=$controls.FindName('IncomingAudio')
$sizeSlider=$controls.FindName('Size')
$opacitySlider=$controls.FindName('Opacity')
$fontSlider=$controls.FindName('FontScale')
$fontValue=$controls.FindName('FontValue')
$fovSlider=$controls.FindName('HorizontalFov')
$markerSlider=$controls.FindName('MarkerScale')
$xSlider=$controls.FindName('OffsetX');$ySlider=$controls.FindName('OffsetY')
$centerZoomSlider=$controls.FindName('CenterZoom')
$rwrZoomSlider=$controls.FindName('RwrZoom')
$missileZoomSlider=$controls.FindName('MissileZoom')
$aircraftSizeSlider=$controls.FindName('AircraftSize')
$missileSizeSlider=$controls.FindName('MissileSize')
$rwrSizeSlider=$controls.FindName('RwrSize')
$datalinkCheckbox=$controls.FindName('DatalinkEnabled')
$modernRwrCheckbox=$controls.FindName('ModernRwrEnabled')
$datalinkRange=$controls.FindName('DatalinkRange')
$mapCheckbox=$controls.FindName('DatalinkOverlayEnabled')
$saRwrCheckbox=$controls.FindName('SaRwrEnabled')
$mapX=$controls.FindName('DatalinkOverlayX');$mapY=$controls.FindName('DatalinkOverlayY')
$mapScale=$controls.FindName('DatalinkOverlayScale')
function Move-DatalinkOverlay([double]$X,[double]$Y){
    $maxX=2560-420*$mapScale.Value;$maxY=1440-420*$mapScale.Value
    $mapX.Value=[Math]::Max(0,[Math]::Min($maxX,([Math]::Min($maxX,$mapX.Value)+$X)))
    $mapY.Value=[Math]::Max(0,[Math]::Min($maxY,([Math]::Min($maxY,$mapY.Value)+$Y)))
    Update-HudVisuals;Draw-DatalinkOverlay
}
function Update-HudVisuals {
    Set-FlightDataScale $controls.FindName('FlightDataScale').Value
    Set-HudAudioVolume $controls.FindName('AudioVolume').Value

    Set-AlertRange ([int]$datalinkRange.SelectedValue)
    $controls.FindName('AlertRangeNm').Value=[int]$datalinkRange.SelectedValue
    Set-LaunchWarningRange ([int]$controls.FindName('LaunchWarningRangeNm').Value)
    $script:rwrWarningEnabled=[bool]$controls.FindName('RwrWarning').IsChecked
    Update-RangeHighlights
    $script:cockpitOnly=[bool]$controls.FindName('CockpitOnly').IsChecked
    $script:flightDataEnabled=[bool]$controls.FindName('FlightDataEnabled').IsChecked
    $controls.FindName('RwrRangeValue').Text=('{0:0} NM' -f ($script:launchWarningRangeM/1852.0))
    $controls.FindName('DatalinkRangeValue').Text=($datalinkRange.SelectedValue+' NM')
    foreach($nm in @(20,40,60)){
        $controls.FindName(('Range'+$nm)).FontWeight=if([int]$datalinkRange.SelectedValue -eq $nm){'Bold'}else{'Normal'}
    }
    $script:saRwrEnabled=[bool]$saRwrCheckbox.IsChecked
    $script:saAircraftTypes=[bool]$controls.FindName('SaAircraftTypes').IsChecked
    $script:datalinkOverlayEnabled=[bool]$mapCheckbox.IsChecked
    $script:datalinkOverlayX=$mapX.Value;$script:datalinkOverlayY=$mapY.Value
    $script:datalinkOverlayScale=$mapScale.Value
    Set-DatalinkRange ([int]$datalinkRange.SelectedValue)
    $script:modernRwrEnabled=[bool]$modernRwrCheckbox.IsChecked
    $script:contentScale=$sizeSlider.Value
    $script:aircraftSize=$aircraftSizeSlider.Value
    $script:missileSize=$missileSizeSlider.Value
    $script:rwrSize=$rwrSizeSlider.Value
    Set-HudFontScale $fontSlider.Value
    $fontValue.Text=('{0:0}%' -f ($fontSlider.Value*100))
    $hud.Opacity=$opacitySlider.Value
    $script:markerOffsetX=0;$script:markerOffsetY=0
    $script:projectionScaleX=$centerZoomSlider.Value;$script:projectionScaleY=$centerZoomSlider.Value
    $script:rwrProjectionZoom=$rwrZoomSlider.Value
    $script:missileProjectionZoom=$missileZoomSlider.Value
    if($script:settingsReady){Save-HudSettings $controls $settingsPath}
    # Manual calibration moves spatial markers; symbol size remains independent.
    [Windows.Controls.Canvas]::SetLeft($dlStatus,(880+$xSlider.Value))
    [Windows.Controls.Canvas]::SetTop($dlStatus,(1340+$ySlider.Value))
}
function Set-HudWindowVisible([bool]$Visible){
    if($script:hudVisibilityChanging){return}
    $script:hudVisibilityChanging=$true
    try{
        if($Visible){if(-not $hudWindow.IsVisible){$hudWindow.Show()}}
        elseif($hudWindow.IsVisible){$hudWindow.Hide()}
    }finally{$script:hudVisibilityChanging=$false}
}
function Update-HudPosition {
    $metrics=if(-not $Demo){[F4HudWindow]::CaptureDcs()}else{$null}
    $source=[Windows.PresentationSource]::FromVisual($hudWindow)
    $dx=1.0;$dy=1.0
    if($source -and $source.CompositionTarget){
        $dx=$source.CompositionTarget.TransformToDevice.M11
        $dy=$source.CompositionTarget.TransformToDevice.M22
    }
    if($metrics){
        $hudWindow.Width=$metrics.Width/$dx;$hudWindow.Height=$metrics.Height/$dy
        $hudWindow.Left=$metrics.X/$dx;$hudWindow.Top=$metrics.Y/$dy
        $script:viewportAspect=[double]$metrics.Width/$metrics.Height
        Update-HudAspect $metrics.Width $metrics.Height
        $signature=('{0},{1} {2}x{3} DPI={4},{5}' -f $metrics.X,$metrics.Y,$metrics.Width,$metrics.Height,$dx,$dy)
        if($script:lastViewportSignature -ne $signature){
            $script:lastViewportSignature=$signature
            $signature | Set-Content -LiteralPath (Join-Path $PSScriptRoot '..\viewport-info.txt') -Encoding UTF8
        }
        $view=Get-CockpitViewState $script:dlFrame (([datetime]::UtcNow-$script:dlLast).TotalSeconds -le 1)
        $viewAllowed=-not $script:cockpitOnly -or $view -eq 'NEAR_COCKPIT'
        Set-HudWindowVisible ($metrics.Active -and $viewAllowed)
        $hudWindow.Opacity=if($metrics.Active -and $viewAllowed){1}else{0}
        $script:hudDisplayState=@{gameActive=$metrics.Active;view=$view;viewAllowed=$viewAllowed;opacity=$hudWindow.Opacity;contentVisibility=[string]$hud.Visibility;windowVisible=$hudWindow.IsVisible;topmost=$hudWindow.Topmost}
        if($hudWindow.Opacity -gt 0){
            if(-not $script:hudWasVisible -or ([datetime]::UtcNow-$script:lastHudRaise).TotalSeconds -ge 1){
                [F4HudWindow]::KeepAboveGame([Windows.Interop.WindowInteropHelper]::new($hudWindow).Handle)
                $script:lastHudRaise=[datetime]::UtcNow
            }
            $script:hudWasVisible=$true
        }else{$script:hudWasVisible=$false}
        if($script:menuBubble){if($metrics.Active -and (-not $script:cockpitOnly -or $view -ne 'EXTERNAL')){$script:menuBubble.Show()}else{$script:menuBubble.Hide()}}
        if($script:cockpitOnly -and $view -eq 'EXTERNAL' -and $controls.IsVisible){Hide-ControlsPanel}
    }else{
        $script:hudWasVisible=$false
        if(-not $Demo){Set-HudWindowVisible $false}
        $script:hudDisplayState=@{gameActive=$false;view='NO_GAME_WINDOW';opacity=0;contentVisibility=[string]$hud.Visibility;windowVisible=$hudWindow.IsVisible}
        $hudWindow.Left=0;$hudWindow.Top=0
        $hudWindow.Width=[Windows.SystemParameters]::PrimaryScreenWidth
        $hudWindow.Height=[Windows.SystemParameters]::PrimaryScreenHeight
        $script:viewportAspect=$hudWindow.Width/$hudWindow.Height
        Update-HudAspect ($hudWindow.Width*$dx) ($hudWindow.Height*$dy)
        $hudWindow.Opacity=if($Demo){1}else{0}
        if($script:menuBubble){$script:menuBubble.Show()}
    }
}
Load-HudSettings $controls $settingsPath
$controls.FindName('SaRwrRangeNm').Value=[int]$datalinkRange.SelectedValue
$script:settingsReady=$true
$script:modernRwrEnabled=[bool]$modernRwrCheckbox.IsChecked
$script:flightDataEnabled=[bool]$controls.FindName('FlightDataEnabled').IsChecked
$controls.FindName('AllOverlaysToggle').Add_Checked({if(-not $script:syncOverlaySwitch){Set-GameOverlaysVisible $true}})
$controls.FindName('AllOverlaysToggle').Add_Unchecked({if(-not $script:syncOverlaySwitch){Set-GameOverlaysVisible $false}})
$modernRwrCheckbox.Add_Checked({Update-HudVisuals;Draw-RwrCue})
$modernRwrCheckbox.Add_Unchecked({Update-HudVisuals;Draw-RwrCue})
$datalinkRange.Add_SelectionChanged({Update-HudVisuals;Draw-Datalink;Draw-DatalinkOverlay})
Connect-DatalinkRangeButtons $controls
$controls.FindName('SaRwrRangeNm').Add_ValueChanged({Select-DatalinkRange ([int]$args[1].NewValue)})
$controls.FindName('LaunchWarningRangeNm').Add_ValueChanged({Set-LaunchWarningRange ([int]$args[1].NewValue);$controls.FindName('RwrRangeValue').Text=('{0:0} NM' -f ($script:launchWarningRangeM/1852));if($script:settingsReady){Save-HudSettings $controls $settingsPath}})
$controls.FindName('RwrWarning').Add_Checked({$script:rwrWarningEnabled=$true;Save-HudSettings $controls $settingsPath})
$controls.FindName('RwrWarning').Add_Unchecked({$script:rwrWarningEnabled=$false;Stop-RadarToneLoop;if($script:receiverAudioPlayer){$script:receiverAudioPlayer.Stop()};if($script:missileTonePlayer){$script:missileTonePlayer.Stop()};$script:missileAudioQueue.Clear();Save-HudSettings $controls $settingsPath})
$controls.FindName('ResetAllCalibration').Add_Click({$centerZoomSlider.Value=1;$missileZoomSlider.Value=1;$rwrZoomSlider.Value=1;Reset-HudOffsets $xSlider $ySlider;Update-HudVisuals})
$controls.FindName('LaunchRange20').Add_Click({$controls.FindName('LaunchWarningRangeNm').Value=20;Update-HudVisuals})
$controls.FindName('LaunchRange40').Add_Click({$controls.FindName('LaunchWarningRangeNm').Value=40;Update-HudVisuals})
$controls.FindName('LaunchRange60').Add_Click({$controls.FindName('LaunchWarningRangeNm').Value=60;Update-HudVisuals})
$controls.FindName('AudioVolume').Add_ValueChanged({Set-HudAudioVolume ([double]$args[1].NewValue);if($script:settingsReady){Save-HudSettings $controls $settingsPath}})
$controls.FindName('AlertRange20').Add_Click({$controls.FindName('AlertRangeNm').Value=20;Update-HudVisuals})
$controls.FindName('AlertRange40').Add_Click({$controls.FindName('AlertRangeNm').Value=40;Update-HudVisuals})
$controls.FindName('AlertRange60').Add_Click({$controls.FindName('AlertRangeNm').Value=60;Update-HudVisuals})
$controls.FindName('CockpitOnly').Add_Checked({Update-HudVisuals})
$controls.FindName('CockpitOnly').Add_Unchecked({Update-HudVisuals})
$controls.FindName('FlightDataEnabled').Add_Checked({Update-HudVisuals;Update-HornetFlightData})
$controls.FindName('FlightDataEnabled').Add_Unchecked({Update-HudVisuals;Update-HornetFlightData})
$mapCheckbox.Add_Checked({Update-HudVisuals;Draw-DatalinkOverlay})
$mapCheckbox.Add_Unchecked({Update-HudVisuals;Draw-DatalinkOverlay})
$controls.FindName('SaAircraftTypes').Add_Checked({Update-HudVisuals;Draw-DatalinkOverlay})
$controls.FindName('SaAircraftTypes').Add_Unchecked({Update-HudVisuals;Draw-DatalinkOverlay})
$saRwrCheckbox.Add_Checked({Update-HudVisuals;Draw-DatalinkOverlay})
$saRwrCheckbox.Add_Unchecked({Update-HudVisuals;Draw-DatalinkOverlay})
$mapX.Add_ValueChanged({Update-HudVisuals;Draw-DatalinkOverlay})
$mapY.Add_ValueChanged({Update-HudVisuals;Draw-DatalinkOverlay})
$mapScale.Add_ValueChanged({Update-HudVisuals;Draw-DatalinkOverlay})
$controls.FindName('MapLeft').Add_Click({Move-DatalinkOverlay -20 0})
$controls.FindName('MapRight').Add_Click({Move-DatalinkOverlay 20 0})
$controls.FindName('MapUp').Add_Click({Move-DatalinkOverlay 0 -20})
$controls.FindName('MapDown').Add_Click({Move-DatalinkOverlay 0 20})
$controls.FindName('ResetDatalinkOverlay').Add_Click({$mapX.Value=180;$mapY.Value=880;$mapScale.Value=1;Update-HudVisuals;Draw-DatalinkOverlay})
$datalinkCheckbox.Add_Checked({Save-HudSettings $controls $settingsPath})
$datalinkCheckbox.Add_Unchecked({Save-HudSettings $controls $settingsPath})
$audio.Add_Checked({Save-HudSettings $controls $settingsPath})
$audio.Add_Unchecked({Save-HudSettings $controls $settingsPath})
$incomingAudioCheckbox.Add_Checked({Save-HudSettings $controls $settingsPath})
$incomingAudioCheckbox.Add_Unchecked({Stop-IncomingToneLoop;$script:incomingNextTone=[datetime]::MinValue;Save-HudSettings $controls $settingsPath})
foreach($slider in @($controls.FindName('FlightDataScale'),$sizeSlider,$fontSlider,$opacitySlider,$xSlider,$ySlider,$centerZoomSlider,$rwrZoomSlider,$missileZoomSlider,$aircraftSizeSlider,$missileSizeSlider,$rwrSizeSlider)){$slider.Add_ValueChanged({Update-HudVisuals})}
$controls.FindName('ResetMissileZoom').Add_Click({$missileZoomSlider.Value=1;Update-HudVisuals})
$controls.FindName('ResetRwrZoom').Add_Click({$rwrZoomSlider.Value=1;Update-HudVisuals})
$controls.FindName('ResetPosition').Add_Click({Reset-HudOffsets $xSlider $ySlider;$centerZoomSlider.Value=1;$fovSlider.Value=90;Update-HudVisuals})
$audio.Add_Checked({$audioLabel.Text='AUDIO ON'})
$audio.Add_Unchecked({Stop-RadarToneLoop;Stop-IncomingToneLoop;if($script:receiverAudioPlayer){$script:receiverAudioPlayer.Stop()};$audioLabel.Text='AUDIO OFF';if($script:missileTonePlayer){$script:missileTonePlayer.Stop()};if($script:incomingTonePlayer){$script:incomingTonePlayer.Stop()};$script:missileAudioQueue.Clear()})
$controls.FindName('HideControls').Add_Click({Hide-ControlsPanel})
$controls.FindName('ExitApplication').Add_Click({Exit-FoxApplication})
$controls.Add_Closing({Handle-MenuClosing $args[1]})
$controls.Add_SourceInitialized({Initialize-ControlsFocus})
if(-not $Demo){
    if($ProfileRoot){
        $fullRoot=[IO.Path]::GetFullPath($ProfileRoot)
        if($fullRoot -match '(?i)(^|[\\/])OneDrive[^\\/]*([\\/]|$)'){throw 'Use a profile outside OneDrive.'}
        $selectedPaths=@((Join-Path $fullRoot 'Logs\F4RwrLink.log'),(Join-Path $fullRoot 'Logs\F4RwrProbe.log'),(Join-Path $fullRoot 'Logs\dcs.log'))
    }else{
        $picker=New-Object Microsoft.Win32.OpenFileDialog
        $picker.Title='Choose up to 3 logs: F4RwrLink, F4RwrProbe, optional mission dcs.log'
        $picker.Filter='Log files (*.log)|*.log|All files (*.*)|*.*'
        $picker.Multiselect=$true
        if(-not $picker.ShowDialog()){exit}
        if($picker.FileNames.Count -gt 3){[void][Windows.MessageBox]::Show('Select at most three logs.');exit}
        $selectedPaths=$picker.FileNames
    }
    foreach($selectedPath in $selectedPaths){
        $script:readers+=([pscustomobject]@{Reader=$null;Partial='';Path=$selectedPath;Retry=[datetime]::MinValue;Buffer=(New-Object char[] 32768)})
    }
}
# Native window flags: HUD passes clicks through and never takes keyboard focus.
$script:bridgeLeasePath=$null;$script:lastBridgePulse=[datetime]::MinValue
if(-not $Demo){
    foreach($selectedPath in $selectedPaths){
        if([IO.Path]::GetFileName($selectedPath) -eq 'F4RwrLink.log'){
            $script:bridgeLeasePath=Join-Path ([IO.Path]::GetDirectoryName($selectedPath)) 'FoxSense.active';break
        }
    }
}
function Update-BridgeHeartbeat {
    if(-not $script:bridgeLeasePath -or ([datetime]::UtcNow-$script:lastBridgePulse).TotalSeconds -lt 1){return}
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($script:bridgeLeasePath))
    [IO.File]::WriteAllText($script:bridgeLeasePath,'FOX SENSE active')
    $script:lastBridgePulse=[datetime]::UtcNow
}
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public sealed class F4ClientMetrics { public int X,Y,Width,Height; public bool Active; }
public static class F4HudWindow {
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct POINT {public int X,Y;}
 [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int n);
 [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h,int n,int v);
 [DllImport("user32.dll")] private static extern bool GetClientRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] private static extern bool ClientToScreen(IntPtr h,ref POINT p);
 [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int cx,int cy,uint flags);
 public static void KeepAboveGame(IntPtr h){if(h!=IntPtr.Zero)SetWindowPos(h,new IntPtr(-1),0,0,0,0,0x213);}
 [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 public static void MakePassive(IntPtr h) { SetWindowLong(h,-20,GetWindowLong(h,-20)|0x20|0x08000000|0x80); }
 public static F4ClientMetrics CaptureDcs(){
  foreach(Process p in Process.GetProcessesByName("DCS")){
   try{
    IntPtr h=p.MainWindowHandle;
    if(h==IntPtr.Zero||IsIconic(h)||!p.MainWindowTitle.Contains("Digital Combat Simulator"))continue;
    RECT r;POINT origin=new POINT();
    if(!GetClientRect(h,out r)||!ClientToScreen(h,ref origin)||r.Right<640||r.Bottom<480)continue;
    uint foreground;GetWindowThreadProcessId(GetForegroundWindow(),out foreground);
    return new F4ClientMetrics{X=origin.X,Y=origin.Y,Width=r.Right-r.Left,Height=r.Bottom-r.Top,Active=foreground==(uint)p.Id||foreground==(uint)Process.GetCurrentProcess().Id};
   }catch{}finally{p.Dispose();}
  }
  return null;
 }
}
"@
$hudWindow.Add_SourceInitialized({
    $handle=[Windows.Interop.WindowInteropHelper]::new($hudWindow).Handle
    [F4HudWindow]::MakePassive($handle)
    Update-HudPosition
})
$script:lastViewportCheck=[datetime]::MinValue
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[timespan]::FromTicks(166667)
$timer.Add_Tick({
    $tickClock=[Diagnostics.Stopwatch]::StartNew()
    try{
        Update-BridgeHeartbeat
        if(([datetime]::UtcNow-$script:lastViewportCheck).TotalMilliseconds -gt 100){Update-HudPosition;$script:lastViewportCheck=[datetime]::UtcNow}
        if($Demo){
            $script:demoStep++
            Set-DatalinkFrame (New-DatalinkDemo $script:demoStep) $true
            if($script:demoStep%60 -eq 1){
                $modes=@('CLEAR','CONTACT','CONTACT','LAUNCH','LAUNCH','TEST','UNAVAILABLE')
                $index=[int][Math]::Floor(($script:demoStep-1)/60)%$modes.Count
                $hours=@(0,2,9,4,7,0,0)
                Show-ReceiverEvent ([pscustomobject]@{Mode=$modes[$index];Hour=$hours[$index];Activity=if($modes[$index] -eq 'LAUNCH'){'launch'}else{'demo'};Category='surface'})
            }
        }else{
            foreach($entry in $script:readers){
                $now=[datetime]::UtcNow
                if($entry.Reader -and ($now-$script:dlLast).TotalSeconds -gt 4 -and $now -ge $entry.Retry){
                    # Reopen only the consented exact path after missing data/rotation.
                    $entry.Reader.Dispose();$entry.Reader=$null;$entry.Partial=''
                }
                if($null -eq $entry.Reader){
                    if($now -lt $entry.Retry){continue}
                    $entry.Retry=$now.AddSeconds(2)
                    try{
                        $stream=[IO.File]::Open($entry.Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                        [void]$stream.Seek(0,[IO.SeekOrigin]::End)
                        $entry.Reader=[IO.StreamReader]::new($stream)
                        $entry.Partial=''
                        $entry.Retry=$now.AddSeconds(4)
                    }catch{continue}
                }
                $reader=$entry.Reader
                if($reader.BaseStream.Length -lt $reader.BaseStream.Position){
                    $reader.DiscardBufferedData();[void]$reader.BaseStream.Seek(0,[IO.SeekOrigin]::Begin);$entry.Partial=''
                }
                $buffer=$entry.Buffer
                $count=$reader.Read($buffer,0,$buffer.Length)
                if($count -gt 0){
                    $lines=($entry.Partial+[string]::new($buffer,0,$count)) -split "`n"
                    $entry.Partial=$lines[-1]
                    if($entry.Partial.Length -gt 65536){$entry.Partial=''}
                    $latestRwr=$null;$latestDl=$null;$latestCamera=$null;$latestMissiles=$null;$latestRwrContacts=$null
                    for($i=0;$i -lt $lines.Length-1;$i++){
                        $line=$lines[$i].TrimEnd("`r")
                        $worldPacket=ConvertFrom-WorldMissileLine $line
                        if($null -ne $worldPacket){$script:exportMissileFrame=$worldPacket;$script:exportMissileLast=[datetime]::UtcNow}
                        $missionPacket=ConvertFrom-WorldMissileLine $line 'F4MODERN_V1|'
                        if($null -ne $missionPacket){$script:missionFrame=$missionPacket;$script:missionLast=[datetime]::UtcNow}
                        $nativePacket=ConvertFrom-NativeRwrLine $line
                        if($null -ne $nativePacket){$script:nativeRwr=$nativePacket;$script:nativeRwrLast=[datetime]::UtcNow}
                        $rwrPacket=ConvertFrom-RwrContactsLine $line
                        if($null -ne $rwrPacket){$latestRwrContacts=$rwrPacket}
                        $missilePacket=ConvertFrom-JesterMissileLine $line
                        if($null -ne $missilePacket){$latestMissiles=$missilePacket}
                        $parsed=ConvertFrom-F4RwrLine $line
                        if($null -ne $parsed){$latestRwr=$parsed}
                        $packet=ConvertFrom-DatalinkLine $line
                        if($null -ne $packet){$latestDl=$packet}
                        $cameraPacket=ConvertFrom-DatalinkLine $line 'F4CAM_V1|'
                        if($null -ne $cameraPacket){$latestCamera=$cameraPacket}
                    }
                    if($null -ne $latestRwrContacts){$script:rwrContacts=$latestRwrContacts;$script:rwrContactsLast=[datetime]::UtcNow}
                    if($null -ne $latestMissiles){$script:jesterMissileFrame=$latestMissiles;$script:jesterMissileLast=[datetime]::UtcNow}
                    if($null -ne $latestRwr){Show-ReceiverEvent $latestRwr}
                    if($null -ne $latestDl){Set-DatalinkFrame $latestDl ($latestDl.state -eq 'DEMO')}
                    if($null -ne $latestCamera){Set-CameraFrame $latestCamera}
                }
            }
            if(([datetime]::UtcNow-$script:lastEvent).TotalSeconds -gt 8){Set-NoSignal 'NO LIVE RWR DATA' 'Check selected log, Jester mods, pause or mission state.'}
        }
        Draw-Datalink
        Update-HornetFlightData
        Draw-RwrCue
        Update-IncomingMissileAudio
        Draw-DatalinkOverlay -RateLimited
        Update-RadarLockAudio
        Update-MissileDiscoveryAudio
        Draw-JesterMissiles
        if(([datetime]::UtcNow-$script:telemetryLast).TotalSeconds -ge 1){
            $script:telemetryLast=[datetime]::UtcNow
            $activeMissiles=Get-ActiveMissileFeed
            $snapshot=@{display=$script:hudDisplayState;time=[datetime]::UtcNow.ToString('o');missileSource=$activeMissiles.Source;exportMissileState=$script:exportMissileFrame.state;missileFeedAge=([datetime]::UtcNow-$activeMissiles.Last).TotalSeconds;cameraAge=([datetime]::UtcNow-$script:dlLast).TotalSeconds;status=$missileStatus.Text;cacheCount=$script:jesterMissileCache.Count;shapes=$missileCanvas.Children.Count;packet=$activeMissiles.Packet;rwrShapes=$rwrCueCanvas.Children.Count;saRangeNm=($script:markerRangeM/1852);rwrRangeNm=($script:alertRangeM/1852);launchWarningRangeNm=($script:launchWarningRangeM/1852);targetHudIntervalMs=(1000.0/60.0);previousTickMs=$script:lastTickMs;actualTimerIntervalMs=$timer.Interval.TotalMilliseconds;radarAudio=$script:radarAudioDiagnostic;radarToneLoop=$script:radarToneLoop;launchToneLoop=$script:incomingToneLoop}
            [IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot) 'hud-runtime.json'),($snapshot|ConvertTo-Json -Depth 8))
            if($missileCanvas.Children.Count -gt 0){[IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot) 'last-missile-drawn.json'),($snapshot|ConvertTo-Json -Depth 8))}
        }
        if(-not $Demo -and $ProfileRoot -and $datalinkCheckbox.IsChecked -and ([datetime]::UtcNow-$script:dlLast).TotalSeconds -gt 3){$dlStatus.Text='WAITING FOR DCS MISSION / AUTO CONNECT'}
        $script:flash=([Math]::Floor([datetime]::UtcNow.TimeOfDay.TotalMilliseconds/250)%2 -eq 0)
        if($script:lastMode -eq 'LAUNCH'){$threat.Opacity=if($script:flash){1}else{0.25};$status.Opacity=$threat.Opacity}
    }catch{[IO.File]::WriteAllText((Join-Path (Split-Path $PSScriptRoot) 'hud-runtime-error.txt'),($_|Out-String));Set-NoSignal 'LOG READ ERROR' 'Restart the HUD and select the active log again.'}finally{$tickClock.Stop();$script:lastTickMs=$tickClock.Elapsed.TotalMilliseconds;$timer.Interval=if(-not $Demo -and $hudWindow.Opacity -eq 0 -and -not $controls.IsVisible){[timespan]::FromMilliseconds(100)}else{[timespan]::FromTicks(166667)}}
})
$script:controlsLoop=[Windows.Threading.DispatcherFrame]::new()
$controls.Add_Closed({$timer.Stop();foreach($entry in $script:readers){if($entry.Reader){$entry.Reader.Dispose()}};if($script:controlsFocus){$script:controlsFocus.Dispose()};if($script:menuFocus){$script:menuFocus.Dispose()};if($script:menuBubble){$script:menuBubble.Close()};$hudWindow.Close();$script:controlsLoop.Continue=$false})
Update-HudVisuals
Update-HudPosition
if($RuntimeControlsTest){if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-RuntimeControls.ps1')){. (Join-Path $PSScriptRoot 'Test-RuntimeControls.ps1')};return}
if($Demo){Set-HudWindowVisible $true}
$timer.Start()
try{
    [void][Windows.Interop.WindowInteropHelper]::new($controls).EnsureHandle()
    Initialize-FloatingMenu
    [Windows.Threading.Dispatcher]::PushFrame($script:controlsLoop)
}finally{
    if($script:bridgeLeasePath){try{[IO.File]::Delete($script:bridgeLeasePath)}catch{}}
    Stop-MenuAudio
    $timer.Stop();foreach($entry in $script:readers){if($entry.Reader){$entry.Reader.Dispose()}}
    if($script:controlsFocus){$script:controlsFocus.Dispose();$script:controlsFocus=$null}
    if($script:menuFocus){$script:menuFocus.Dispose();$script:menuFocus=$null}
    if($script:menuBubble){$script:menuBubble.Close();$script:menuBubble=$null}
    $hudWindow.Close()
}
