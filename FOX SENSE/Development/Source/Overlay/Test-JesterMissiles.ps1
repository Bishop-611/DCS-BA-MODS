$missileCamera=@{p=@{x=0;y=0;z=0};forward=@{x=1;y=0;z=0};up=@{x=0;y=1;z=0};right=@{x=0;y=0;z=1}}
$packet='F4JESTER_MISSILES_V1|{"state":"AWARENESS","sequence":1,"missiles":[{"id":"m1","identity":"UNKNOWN","age_s":0,"ned":{"x":1000,"y":100,"z":-100}}]}'
$script:jesterMissileFrame=ConvertFrom-JesterMissileLine $packet
if($null -eq $script:jesterMissileFrame){throw 'Jester missile parser failed'}
if($null -ne (ConvertFrom-JesterMissileLine 'F4JESTER_MISSILES_V1|{}')){throw 'Malformed missile packet accepted'}
Set-DatalinkFrame ([pscustomobject]@{camera=$missileCamera;ownship=@{x=0;y=0;z=0}})
$script:jesterMissileLast=[datetime]::UtcNow
$script:jesterMissileCache=@{};$script:jesterProcessedPacket=[datetime]::MinValue
Draw-JesterMissiles
if($missileCanvas.Children.Count -ne 1){throw 'Live missile missing'}
$triangle=$missileCanvas.Children[0].Children[0]
if($triangle -isnot [Windows.Shapes.Path] -or $triangle.Tag -ne 'Detected'){throw 'Detected missile must use open corners'}
if([Windows.Controls.Canvas]::GetLeft($missileCanvas.Children[0]) -le 1280 -or [Windows.Controls.Canvas]::GetTop($missileCanvas.Children[0]) -ge 720){throw 'Relative NED mapping incorrect'}
$script:jesterMissileFrame=[pscustomobject]@{state='AWARENESS';missiles=@()}
$script:jesterMissileLast=$script:jesterMissileLast.AddMilliseconds(1)
Draw-JesterMissiles
if($missileCanvas.Children.Count -ne 1 -or $missileCanvas.Children[0].Children[0].Tag -ne 'Detected'){throw 'Lost missile must use dashed triangle'}
$script:jesterMissileCache['m1'].Seen=[datetime]::UtcNow.AddSeconds(-3.1)
Draw-JesterMissiles
if($missileCanvas.Children.Count -ne 0){throw 'Lost missile retained more than 3 seconds'}
if((Get-JesterMissileCue $missileCamera @{x=-1000;y=0;z=100}).Edge -notlike '*AFT*'){throw 'Rear missile edge cue missing'}
Write-Output 'PASS: missile parser, red triangle, NED projection, dashed lost-contact marker, 3-second removal, rear edge cue'
