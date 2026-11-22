$line='F4NATIVE_RWR_V1|{"state":"LIVE","contacts":[{"id":"42","type_name":"RPC_5N62V","azimuth":1.5707963267948966,"signal":"lock"}]}'
$packet=ConvertFrom-NativeRwrLine $line
if($null -eq $packet -or $packet.contacts[0].native_code -ne '5' -or $packet.contacts[0].activity -ne 'lock'){throw 'Native SA-5 decode failed'}
$script:modernRwrEnabled=$true;$script:nativeRwr=$packet;$script:nativeRwrLast=[datetime]::UtcNow
$script:rwrContacts=[pscustomobject]@{state='UNAVAILABLE';contacts=@()};$script:rwrContactsLast=[datetime]::UtcNow
$script:lastEvent=[datetime]::MinValue
$f=[pscustomobject]@{state='LIVE_POSITIONS';camera=$camera;own_heading=0;ownship=@{x=0;y=0;z=0};tracks=@()}
Set-DatalinkFrame $f;Draw-RwrCue
if($rwrCueCanvas.Children.Count -ne 1){throw 'Native JHMCS data incorrectly gated by unavailable Jester'}
$before=[Windows.Controls.Canvas]::GetLeft($rwrCueCanvas.Children[0])
$f.camera=$yawCamera;Set-DatalinkFrame $f;Draw-RwrCue
$after=[Windows.Controls.Canvas]::GetLeft($rwrCueCanvas.Children[0])
if([Math]::Abs($after-$before) -lt 1){throw 'Enhanced JHMCS did not follow head yaw'}
$script:dlLast=[datetime]::UtcNow.AddSeconds(-3);Draw-RwrCue
if($rwrCueCanvas.Children.Count -ne 0){throw 'Enhanced JHMCS retained stale camera'}
$f.camera=$camera;Set-DatalinkFrame $f
$script:rwrContacts=[pscustomobject]@{state='LIVE';contacts=@([pscustomobject]@{hour=12;symbol1='seven';activity='search'})}
$script:rwrContactsLast=[datetime]::UtcNow
$script:nativeRwr=[pscustomobject]@{state='BLOCKED';contacts=@()};Draw-RwrCue
if($rwrCueCanvas.Children.Count -ne 1 -or $rwrCueCanvas.Children[0].Children[1].Text -ne '7'){throw 'Jester fallback after Export blocked failed'}
$script:nativeRwr=$packet;$script:nativeRwrLast=[datetime]::UtcNow;$script:modernRwrEnabled=$false;Draw-RwrCue
if($rwrCueCanvas.Children[0].Children[1].Text -ne '7'){throw 'Original mode consumed enhanced source'}
$a=Get-RwrAzimuthCue $camera 0 3.1
$b=Get-RwrAzimuthCue $camera 0 3.2
if([Math]::Abs($a.X-$b.X) -lt 0.01){throw 'Native fractional azimuth was rounded'}
if($null -ne (ConvertFrom-NativeRwrLine ($line.Replace('1.5707963267948966','99')))){throw 'Invalid native azimuth accepted'}
$script:nativeRwr=$null
Write-Output 'PASS: enhanced native JHMCS, head yaw, camera timeout, Jester fallback, original switch and fractional bearing (synthetic fixtures)'
