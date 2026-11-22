$script:alertRangeM=20*1852.0
$script:cockpitOnly=$true
function Set-AlertRange([int]$Nm){if($Nm -notin @(20,40,60)){$Nm=20};$script:alertRangeM=$Nm*1852.0}
function Limit-RwrFrame($Frame){
    $contacts=@($Frame.contacts|Where-Object {
        if($null -eq $_.range_m){$true}else{
            $r=[double]$_.range_m
            [double]::IsNaN($r) -or [double]::IsInfinity($r) -or $r -lt 0 -or $r -le $script:alertRangeM
        }
    })
    return [pscustomobject]@{state=$Frame.state;source=$Frame.source;contacts=$contacts}
}
function Test-AlertMissileRange($Entry,$Packet){
    $distance=0.0
    if(Test-JesterVector $Entry.ned){foreach($a in @('x','y','z')){$distance+=$Entry.ned.$a*$Entry.ned.$a}}
    elseif(Test-JesterVector $Entry.world){
        $own=$Packet.ownship
        if(-not (Test-JesterVector $own) -and $null -ne $script:dlFrame -and ([datetime]::UtcNow-$script:dlLast).TotalSeconds -le 1){$own=$script:dlFrame.ownship}
        if(-not (Test-JesterVector $own)){return $true}
        foreach($a in @('x','y','z')){$d=$Entry.world.$a-$own.$a;$distance+=$d*$d}
    }else{return $true}
    return $distance -le $script:alertRangeM*$script:alertRangeM
}
function Get-CockpitViewState($Frame,[bool]$Fresh){
    if(-not $Fresh -or $null -eq $Frame -or -not (Test-JesterVector $Frame.ownship) -or -not (Test-JesterVector $Frame.camera.p)){return 'UNKNOWN'}
    $distance=0.0;foreach($a in @('x','y','z')){$d=$Frame.camera.p.$a-$Frame.ownship.$a;$distance+=$d*$d}
    if($distance -le 100){return 'NEAR_COCKPIT'}
    return 'EXTERNAL'
}
