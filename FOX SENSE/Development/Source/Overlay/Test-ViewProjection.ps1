$script:projectionScaleX=1;$script:projectionScaleY=1;$script:markerOffsetX=0;$script:markerOffsetY=0;$script:missileProjectionZoom=1;$script:viewportAspect=16.0/9
$camera=@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};right=@{x=0;y=0;z=1};up=@{x=0;y=1;z=0}}
foreach($fov in @(30,60,90,120)){
 $camera.projection=@{hfov_deg=$fov}
 $position=@{x=10000;y=500;z=600}
 $plane=Get-TrackProjection $camera $position 90;$missile=Get-JesterMissileCue $camera $position
 if($null -eq $plane -or [Math]::Abs($plane.X-$missile.X) -gt 0.001 -or [Math]::Abs($plane.Y-$missile.Y) -gt 0.001){throw 'Aircraft/missile projections disagree under camera FOV'}
}
$camera.projection=@{hfov_deg=90};$p90=Get-ViewProjection $camera @{x=1000;y=0;z=100} 90
$camera.projection=@{hfov_deg=60};$p60=Get-ViewProjection $camera @{x=1000;y=0;z=100} 90
if([Math]::Abs(($p60.X-1280)/($p90.X-1280)-[Math]::Sqrt(3)) -gt 0.001){throw 'FOV focal scaling incorrect'}
$camera.projection=@{hfov_deg=90};$script:viewportAspect=32.0/9
$p=Get-ViewProjection $camera @{x=1000;y=100;z=0} 90
if([Math]::Abs($p.Y-464) -gt 0.001){throw 'Ultrawide projection aspect incorrect'}
$camera.p=@{x=100;y=20;z=-30};$center=Get-ViewProjection $camera @{x=1100;y=20;z=-30} 90
if($center.X -ne 1280 -or $center.Y -ne 720){throw 'Camera translation was ignored'}
$camera.projection=@{hfov_deg=[double]::NaN}
if($null -eq (Get-ViewProjection $camera @{x=1100;y=20;z=-30} 90)){throw 'Invalid optional FOV did not fall back'}
$script:viewportAspect=16.0/9
$camera.p=@{x=0;y=0;z=0};$camera.forward=@{x=0;y=0;z=1};$camera.right=@{x=-1;y=0;z=0};$camera.up=@{x=0;y=1;z=0};$camera.projection=@{hfov_deg=90}
$turned=Get-ViewProjection $camera @{x=-100;y=100;z=1000} 90
if([Math]::Abs($turned.X-1408) -gt 0.001 -or [Math]::Abs($turned.Y-592) -gt 0.001){throw 'Head yaw projection incorrect'}
$camera.right=@{x=0;y=1;z=0};$camera.up=@{x=1;y=0;z=0}
$rolled=Get-ViewProjection $camera @{x=100;y=100;z=1000} 90
if([Math]::Abs($rolled.X-1408) -gt 0.001 -or [Math]::Abs($rolled.Y-592) -gt 0.001){throw 'Head roll projection incorrect'}
Write-Output 'PASS: shared aircraft/missile projection, supplied FOV changes, ultrawide aspect, camera translation and optional-FOV fallback; no live FOV source verified'
