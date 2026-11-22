$script:saRwrEnabled=$true;$script:datalinkOverlayEnabled=$true;$script:modernRwrEnabled=$false
$script:dlFrame=$null;$script:dlLast=[datetime]::MinValue;$script:lastEvent=[datetime]::MinValue
$script:rwrContacts=[pscustomobject]@{state='LIVE';contacts=@([pscustomobject]@{hour=12;symbol1='seven';activity='lock'})}
$script:rwrContactsLast=[datetime]::UtcNow
Draw-DatalinkOverlay
$layer=@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'RwrBearingLayer'})[0]
$glyph=@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrContact'})
if($glyph.Count -ne 1 -or $glyph[0].Children[1].Text -ne '7' -or $glyph[0].Children.Count -ne 3){throw 'SA failed to show Jester RWR lock without position/camera export'}
$point=Get-SaRwrPoint $script:rwrContacts.contacts[0]
if([Math]::Abs($point.X-210) -gt 0.001 -or $point.Y -ne 71){throw 'SA body bearing geometry incorrect'}
Set-DatalinkRange 40
$other=Get-SaRwrPoint $script:rwrContacts.contacts[0]
if($point.X -ne $other.X -or $point.Y -ne $other.Y){throw 'SA RWR incorrectly interpreted aircraft range as threat distance'}
$script:rwrContacts.contacts=@([pscustomobject]@{hour=0;activity='launch';symbol1='five'})
$layer=New-SaRwrLayer
if(@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrContact'}).Count -ne 0 -or @($layer.Children|Where-Object {$_.Tag -eq 'SaRwrStatus'})[0].Text -notmatch 'BRG UNKNOWN'){throw 'SA fabricated unknown bearing'}
$script:rwrContacts=$null;$script:modernRwrEnabled=$true
$script:nativeRwr=ConvertFrom-NativeRwrLine 'F4NATIVE_RWR_V1|{"state":"LIVE","contacts":[{"id":"42","type_name":"RPC_5N62V","azimuth":1.5707963267948966,"signal":"missile_radio_guided"}]}'
$script:nativeRwrLast=[datetime]::UtcNow;$script:flash=$false
$layer=New-SaRwrLayer;$glyph=@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrContact'})[0]
if($glyph.Children[1].Text -ne '5' -or $glyph.Opacity -ne 0.3){throw 'SA native type/launch rendering failed'}
$script:flash=$true;$layer=New-SaRwrLayer
if(@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrContact'})[0].Opacity -ne 1){throw 'SA launch flashing failed'}
$script:nativeRwrLast=[datetime]::UtcNow.AddSeconds(-3);$layer=New-SaRwrLayer
if(@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrContact'}).Count -ne 0 -or @($layer.Children|Where-Object {$_.Tag -eq 'SaRwrStatus'})[0].Text -ne 'RWR: NO DATA'){throw 'SA stale RWR contacts retained'}
$script:rwrContacts=[pscustomobject]@{state='TEST';contacts=@()};$script:rwrContactsLast=[datetime]::UtcNow
$script:nativeRwrLast=[datetime]::UtcNow;$layer=New-SaRwrLayer
if(@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrContact'}).Count -ne 1){throw 'Fallback Jester test incorrectly overrode active Export source'}
$script:rwrContacts=[pscustomobject]@{state='LIVE';contacts=@()};$script:modernRwrEnabled=$false
$layer=New-SaRwrLayer
if(@($layer.Children|Where-Object {$_.Tag -eq 'SaRwrStatus'})[0].Text -ne 'RWR: NO REPORTED CONTACTS'){throw 'SA clear not represented'}
$script:saRwrEnabled=$false;Draw-DatalinkOverlay
if(@($datalinkOverlayCanvas.Children[0].Children|Where-Object {$_.Tag -eq 'RwrBearingLayer'}).Count -ne 0){throw 'SA RWR checkbox failed'}
$c=Load-Xaml 'Controls.xaml'
if(-not $c.FindName('SaRwrEnabled').IsChecked){throw 'SA RWR must default on for old settings'}
$c.FindName('SaRwrEnabled').IsChecked=$false
$path=Join-Path $env:TEMP ('fox-sa-'+[guid]::NewGuid().ToString('N')+'.json')
try{Save-HudSettings $c $path;$loaded=Load-Xaml 'Controls.xaml';Load-HudSettings $loaded $path;if($loaded.FindName('SaRwrEnabled').IsChecked){throw 'SA RWR setting not saved'}}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
$script:saRwrEnabled=$true;$script:datalinkOverlayEnabled=$false;$script:nativeRwr=$null
Set-DatalinkRange 20
Write-Output 'PASS: SA RWR without position/camera, shared native/Jester sources, lock/launch, range independence, unknown bearing, stale/test/clear states and checkbox persistence'
