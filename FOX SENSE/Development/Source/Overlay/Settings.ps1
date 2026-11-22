function Save-HudSettings($Controls,[string]$Path){
    $values=@{}
    foreach($name in @('FlightDataScale','Size','FontScale','Opacity','CenterZoom','MissileZoom','RwrZoom','AircraftSize','MissileSize','RwrSize','DatalinkOverlayX','DatalinkOverlayY','DatalinkOverlayScale','FloatingMenuX','FloatingMenuY','AlertRangeNm','LaunchWarningRangeNm','AudioVolume')){
        $control=$Controls.FindName($name)
        if($control){$values[$name]=[double]$control.Value}
    }
    foreach($name in @('Audio','RwrWarning','IncomingAudio','DatalinkEnabled','ModernRwrEnabled','DatalinkOverlayEnabled','SaRwrEnabled','SaAircraftTypes','CockpitOnly','FlightDataEnabled')){
        $control=$Controls.FindName($name)
        if($control){$values[$name]=[bool]$control.IsChecked}
    }
    $range=$Controls.FindName('DatalinkRange')
    if($range -and [string]$range.SelectedValue -in @('20','40','60')){$values['DatalinkRangeNm']=[int]$range.SelectedValue}
    $json=@{version=1;values=$values}|ConvertTo-Json -Depth 3
    [IO.File]::WriteAllText($Path,$json,[Text.UTF8Encoding]::new($false))
}
function Load-HudSettings($Controls,[string]$Path){
    if(-not [IO.File]::Exists($Path)){return}
    try{
        $data=[IO.File]::ReadAllText($Path)|ConvertFrom-Json
        if($data.version -ne 1){return}
        if([string]$data.values.DatalinkRangeNm -eq '30'){$data.values.DatalinkRangeNm=40}
        $range=$Controls.FindName('DatalinkRange')
        if($range -and [string]$data.values.DatalinkRangeNm -in @('20','40','60')){$range.SelectedValue=[string]$data.values.DatalinkRangeNm}
        if($null -eq $data.values.LaunchWarningRangeNm){$Controls.FindName('LaunchWarningRangeNm').Value=[int]$range.SelectedValue}
        foreach($name in @('FlightDataScale','Size','FontScale','Opacity','CenterZoom','MissileZoom','RwrZoom','AircraftSize','MissileSize','RwrSize','DatalinkOverlayX','DatalinkOverlayY','DatalinkOverlayScale','FloatingMenuX','FloatingMenuY','AlertRangeNm','LaunchWarningRangeNm','AudioVolume')){
            $control=$Controls.FindName($name);$value=$data.values.$name
            if($name -eq 'MissileZoom' -and $null -eq $value){$value=$data.values.CenterZoom}
            if($null -eq $control -or $null -eq $value){continue}
            try{$number=[double]$value}catch{continue}
            if([double]::IsNaN($number) -or [double]::IsInfinity($number)){continue}
            $control.Value=[Math]::Max($control.Minimum,[Math]::Min($control.Maximum,$number))
        }
        foreach($name in @('Audio','RwrWarning','IncomingAudio','DatalinkEnabled','ModernRwrEnabled','DatalinkOverlayEnabled','SaRwrEnabled','SaAircraftTypes','CockpitOnly','FlightDataEnabled')){
            $control=$Controls.FindName($name);$value=$data.values.$name
            if($name -eq 'MissileZoom' -and $null -eq $value){$value=$data.values.CenterZoom}
            if($control -and $value -is [bool]){$control.IsChecked=$value}
        }
    }catch{ return }
}
