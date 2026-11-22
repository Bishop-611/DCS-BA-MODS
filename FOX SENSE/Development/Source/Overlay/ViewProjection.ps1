function Get-ViewProjection($Camera,$Position,[double]$HorizontalFov=90){
    foreach($v in @($Camera.p,$Camera.forward,$Camera.right,$Camera.up,$Position)){if(-not (Test-JesterVector $v)){return $null}}
    $fov=$HorizontalFov
    if($null -ne $Camera.projection -and $Camera.projection.hfov_deg -is [ValueType]){
        $candidate=[double]$Camera.projection.hfov_deg
        if(-not [double]::IsNaN($candidate) -and -not [double]::IsInfinity($candidate) -and $candidate -gt 1 -and $candidate -lt 179){$fov=$candidate}
    }
    $c=[double[]]@($Camera.p.x,$Camera.p.y,$Camera.p.z,$Camera.forward.x,$Camera.forward.y,$Camera.forward.z,$Camera.right.x,$Camera.right.y,$Camera.right.z,$Camera.up.x,$Camera.up.y,$Camera.up.z)
    $v=[FoxGeometry]::E($c,[double[]]@($Position.x,$Position.y,$Position.z),$fov,$script:viewportAspect)
    if($null -eq $v){return $null}
    return [pscustomobject]@{X=$v[0];Y=$v[1];Forward=$v[2];Right=$v[3];Up=$v[4]}
}
