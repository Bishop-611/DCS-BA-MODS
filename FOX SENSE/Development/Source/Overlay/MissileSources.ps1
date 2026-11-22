$script:exportMissileFrame=$null;$script:exportMissileLast=[datetime]::MinValue
$script:missionFrame=$null;$script:missionLast=[datetime]::MinValue
$script:missileSelectedSource='JESTER'
$script:hostileMissileMarkersOnly=$true
function Test-HostileMissileMarker($Entry){
    return -not $script:hostileMissileMarkersOnly -or ($Entry.identity -eq 'HOSTILE' -and $Entry.own_launch -ne $true)
}
function ConvertFrom-WorldMissileLine([string]$Line,[string]$Prefix='F4EXPORT_MISSILES_V1|'){
    $index=$Line.IndexOf($Prefix)
    if($index -lt 0 -or $Line.Length -gt 65536){return $null}
    try{
        $f=$Line.Substring($index+$Prefix.Length)|ConvertFrom-Json
        if($f.state -notin @('LIVE','BLOCKED','UNAVAILABLE','SIM_RECEIVER','NO_PLAYER') -or @($f.missiles).Count -gt 64){return $null}
        if($null -ne $f.sample_time){$t=[double]$f.sample_time;if([double]::IsNaN($t) -or [double]::IsInfinity($t)){return $null}}
        if($f.state -eq 'SIM_RECEIVER'){
            if(-not (Test-JesterVector $f.ownship) -or @($f.emitters).Count -gt 64){return $null}
            if($null -ne $f.own_heading){$h=[double]$f.own_heading;if([double]::IsNaN($h) -or [double]::IsInfinity($h)){return $null}}
            foreach($e in @($f.emitters)){if(-not (Test-JesterVector $e.p)){return $null}}
        }
        foreach($entry in @($f.missiles)){
            if(-not $entry.id -or $entry.identity -notin @('FRIENDLY','HOSTILE','UNKNOWN') -or -not (Test-JesterVector $entry.p)){return $null}
        }
        return $f
    }catch{return $null}
}
function ConvertTo-MissilePacket($Frame){
    $entries=@($Frame.missiles|ForEach-Object {[pscustomobject]@{id=$_.id;identity=$_.identity;type=$_.type;inbound=$_.inbound;own_launch=$_.own_launch;age_s=0;world=$_.p}})
    return [pscustomobject]@{state='AWARENESS';sequence=$Frame.sequence;sample_time=$Frame.sample_time;ownship=$Frame.ownship;missiles=$entries}
}
function Get-ActiveMissileFeed {
    $now=[datetime]::UtcNow
    if($script:modernRwrEnabled){
        if($null -ne $script:exportMissileFrame -and $script:exportMissileFrame.state -eq 'LIVE' -and ($now-$script:exportMissileLast).TotalSeconds -le 1.5 -and @($script:exportMissileFrame.missiles).Count -gt 0){
            return [pscustomobject]@{Packet=(ConvertTo-MissilePacket $script:exportMissileFrame);Last=$script:exportMissileLast;Source='EXPORT'}
        }
        if($null -ne $script:missionFrame -and $script:missionFrame.state -eq 'SIM_RECEIVER' -and ($now-$script:missionLast).TotalSeconds -le 1.5 -and @($script:missionFrame.missiles).Count -gt 0){
            return [pscustomobject]@{Packet=(ConvertTo-MissilePacket $script:missionFrame);Last=$script:missionLast;Source='MISSION'}
        }
    }
    return [pscustomobject]@{Packet=$script:jesterMissileFrame;Last=$script:jesterMissileLast;Source='JESTER'}
}
function Get-MissionRwrFrame {
    if($null -eq $script:missionFrame -or $script:missionFrame.state -ne 'SIM_RECEIVER' -or ([datetime]::UtcNow-$script:missionLast).TotalSeconds -gt 1.5){return $null}
    $f=$script:missionFrame;$own=$f.ownship
    if(-not (Test-JesterVector $own) -or $null -eq $f.own_heading){return $null}
    $contacts=@()
    foreach($e in @($f.emitters)){
        if(-not (Test-JesterVector $e.p)){continue}
        $a=[Math]::Atan2(($e.p.z-$own.z),($e.p.x-$own.x))-[double]$f.own_heading
        $hour=(($a*6/[Math]::PI)%12+12)%12;if($hour -eq 0){$hour=12}
        $activity=switch($e.mode){LAUNCH {'launch'} TRACK {'lock'} default {'search'}}
        $distance=0.0;foreach($axis in @('x','y','z')){$d=$e.p.$axis-$own.$axis;$distance+=$d*$d}
        $contacts+=[pscustomobject]@{hour=$hour;type1=$e.type;native_code=$e.symbol;activity=$activity;range_m=[Math]::Sqrt($distance)}
    }
    return [pscustomobject]@{state='LIVE';source='MISSION';contacts=$contacts}
}
