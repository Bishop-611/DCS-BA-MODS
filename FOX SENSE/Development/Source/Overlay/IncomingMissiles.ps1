$script:launchWarningRangeM=20*1852.0
function Set-LaunchWarningRange([int]$Nm){if($Nm -notin @(20,40,60)){$Nm=20};$script:launchWarningRangeM=$Nm*1852.0}
$script:incomingSamples=@{};$script:incomingSource='';$script:incomingPacketKey=''
$script:incomingThreatActive=$false;$script:incomingNextTone=[datetime]::MinValue
$script:incomingTonePlayer=$null;$script:incomingPlaybackRequests=0
function Test-MissileApproach($Previous,$Relative,$World,[double]$Time){
 if($null -eq $Previous){return $false}
 return [FoxGeometry]::C([double[]]@($Relative.x,$Relative.y,$Relative.z),[double[]]@($Previous.Relative.x,$Previous.Relative.y,$Previous.Relative.z),[double[]]@($World.x,$World.y,$World.z),[double[]]@($Previous.World.x,$Previous.World.y,$Previous.World.z),($Time-$Previous.Time),[Math]::Max($script:markerRangeM,$script:launchWarningRangeM))
}
function Update-IncomingMissileAudio([datetime]$Now=[datetime]::UtcNow){
    $trackingRangeM=[Math]::Max($script:markerRangeM,$script:launchWarningRangeM)
    $feed=Get-ActiveMissileFeed;$packet=$feed.Packet
    $key=$feed.Source+':'+$feed.Last.Ticks+':'+[string]$packet.sequence
    if($script:incomingSource -ne $feed.Source){$script:incomingSamples=@{};$script:incomingSource=$feed.Source;$script:incomingPacketKey=''}
    $valid=$null -ne $packet -and $packet.state -eq 'AWARENESS' -and ($Now-$feed.Last).TotalSeconds -le 1.5
    $script:incomingMarkerLast=if($valid){$feed.Last}else{[datetime]::MinValue}
    if($valid -and $key -ne $script:incomingPacketKey){
        $script:incomingPacketKey=$key;$updated=@{}
        $own=$null
        if(Test-JesterVector $packet.ownship){$own=$packet.ownship}
        elseif(($Now-$script:dlLast).TotalSeconds -le 1 -and $null -ne $script:dlFrame -and (Test-JesterVector $script:dlFrame.ownship)){$own=$script:dlFrame.ownship}
        $time=if($null -ne $packet.sample_time){[double]$packet.sample_time}else{$feed.Last.Ticks/10000000.0}
        if($null -ne $own -and -not [double]::IsNaN($time) -and -not [double]::IsInfinity($time)){
            foreach($entry in @($packet.missiles)){
                if(-not $entry.id -or [double]$entry.age_s+($Now-$feed.Last).TotalSeconds -gt 1.5){continue}
                if($entry.own_launch -eq $true){continue}
                if(Test-JesterVector $entry.world){$world=$entry.world}
                elseif(Test-JesterVector $entry.ned){$r=$entry.ned;$world=@{x=$own.x+$r.x;y=$own.y-$r.z;z=$own.z+$r.y}}
                else{continue}
                $relative=@{};$distance=0.0
                foreach($a in @('x','y','z')){$relative[$a]=$world.$a-$own.$a;$distance+=$relative[$a]*$relative[$a]}
                if($distance -gt $trackingRangeM*$trackingRangeM){continue}
                $previous=$script:incomingSamples[[string]$entry.id];$count=0
                if($feed.Source -ne 'MISSION' -and (Test-MissileApproach $previous $relative $world $time)){$count=1;if($null -ne $previous){$count+=$previous.Count}}
                # Explicit target assignment exists only in the optional mission feed.
                $direct=$feed.Source -eq 'MISSION' -and $entry.inbound -eq $true
                $updated[[string]$entry.id]=[pscustomobject]@{Identity=$entry.identity;World=$world;Relative=$relative;Time=$time;Count=$count;Incoming=($direct -or $count -ge 2)}
            }
        }
        $script:incomingSamples=$updated
    }
    $active=$valid -and @($script:incomingSamples.Values|Where-Object {$_.Incoming -and $_.Identity -ne 'FRIENDLY' -and ($_.Relative.x*$_.Relative.x+$_.Relative.y*$_.Relative.y+$_.Relative.z*$_.Relative.z) -le $script:launchWarningRangeM*$script:launchWarningRangeM}).Count -gt 0
    $script:incomingThreatActive=$active
    $enabled=$audio.IsChecked -and ($null -eq $incomingAudioCheckbox -or $incomingAudioCheckbox.IsChecked)
    if(-not $active -or -not $enabled){Stop-IncomingToneLoop;return}
    if($script:incomingToneLoop){return}
    Stop-RadarToneLoop
    Initialize-WarningPlayer 4
    $script:incomingToneLoop=$true
    if(-not $SelfTest -and -not $RenderPreview){
        if($script:missileTonePlayer){$script:missileTonePlayer.Stop()}
        $script:incomingTonePlayer.Position=[timespan]::Zero;$script:incomingTonePlayer.Play()
    }
    $script:incomingPlaybackRequests++
}
