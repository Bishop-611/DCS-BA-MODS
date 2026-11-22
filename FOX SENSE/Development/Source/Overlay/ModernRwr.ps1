# Native sensor decoder and shared receiver selection for JHMCS and SA.
$script:modernRwrEnabled=$false
$script:nativeRwr=$null;$script:nativeRwrLast=[datetime]::MinValue
function ConvertFrom-NativeRwrLine([string]$Line){
    $prefix='F4NATIVE_RWR_V1|';$i=$Line.IndexOf($prefix)
    if($i -lt 0 -or $Line.Length -gt 65536){return $null}
    try{
        $packet=$Line.Substring($i+$prefix.Length)|ConvertFrom-Json
        if($packet.state -notin @('LIVE','BLOCKED','UNAVAILABLE') -or @($packet.contacts).Count -gt 64){return $null}
        $contacts=@()
        foreach($c in @($packet.contacts)){
            $hour=0.0
            if($null -ne $c.azimuth){
                $az=[double]$c.azimuth
                if([double]::IsNaN($az) -or [double]::IsInfinity($az) -or [Math]::Abs($az) -gt 2*[Math]::PI){return $null}
                # DCS native azimuth is retained at full precision; verify handedness in cockpit.
                $hour=(($az*6/[Math]::PI)%12+12)%12
                if($hour -eq 0){$hour=12}
            }
            $activity=switch([string]$c.signal){'scan' {'search'} 'lock' {'lock'} 'missile_radio_guided' {'launch'} 'track_while_scan' {'track'} default {'unknown'}}
            $name=[string]$c.type_name
            $code=if($name -eq 'RPC_5N62V'){'5'}else{Get-HornetThreatCode ([pscustomobject]@{type1=$name})}
            $contacts+=[pscustomobject]@{id=$c.id;hour=$hour;activity=$activity;type1=$name;native_code=$code}
        }
        return [pscustomobject]@{state=$packet.state;contacts=$contacts}
    }catch{return $null}
}
