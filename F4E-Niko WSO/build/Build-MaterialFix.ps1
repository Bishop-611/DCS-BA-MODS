$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
public static class NormalHeaderCheck {
 public static bool OnlyArraySizeChanged(byte[] before,byte[] after) {
  if(before.Length!=after.Length || before.Length<148 || before[140]!=0 || after[140]!=1) return false;
  for(int i=0;i<before.Length;i++) if(i!=140 && before[i]!=after[i])return false;
  return true;
 }
}
'@
$source=Join-Path $PSScriptRoot 'package-fox-platoon/Liveries/F-4E-45MC/F4E-FOX PLATOON'
$rough=Join-Path $PSScriptRoot 'Release/v0.10-Matte/Liveries/F-4E-45MC/F4E-FOX PLATOON'
$dest=Join-Path $PSScriptRoot 'Release/v0.11-Material-Fix/Liveries/F-4E-45MC/F4E-FOX PLATOON'
[IO.Directory]::CreateDirectory($dest)|Out-Null
$files=@(Get-ChildItem -LiteralPath $source -File -Filter '*_Normal.dds')
if($files.Count -ne 9){throw 'Expected nine original normal maps.'}
$report=@(foreach($file in $files){
 $before=[IO.File]::ReadAllBytes($file.FullName)
 if([Text.Encoding]::ASCII.GetString($before,84,4) -ne 'DX10' -or [BitConverter]::ToUInt32($before,128) -ne 83 -or [BitConverter]::ToUInt32($before,132) -ne 3 -or [BitConverter]::ToUInt32($before,140) -ne 0){throw 'Unexpected BC5 normal header.'}
 $after=[byte[]]$before.Clone()
 # DDS_HEADER_DXT10.arraySize: invalid zero -> one 2D texture. No pixel data changes.
 $after[140]=1
 if(-not [NormalHeaderCheck]::OnlyArraySizeChanged($before,$after)){throw 'Unexpected non-header change.'}
 $out=Join-Path $dest $file.Name
 [IO.File]::WriteAllBytes($out,$after)
 if([BitConverter]::ToUInt32([IO.File]::ReadAllBytes($out),140) -ne 1){throw 'Header write verification failed.'}
 "PASS: $($file.Name): DXGI 83/BC5, 2D, arraySize 0 -> 1; every other byte unchanged."
})
$r=@(Get-ChildItem -LiteralPath $rough -File -Filter '*_RoughMet.dds')
if($r.Count -ne 12){throw 'Expected twelve matte material maps.'}
foreach($f in $r){$out=Join-Path $dest $f.Name;Copy-Item -LiteralPath $f.FullName -Destination $out -Force;if((Get-FileHash -LiteralPath $out).Hash -ne (Get-FileHash -LiteralPath $f.FullName).Hash){throw 'Matte map copy changed.'}}
$report+='PASS: 12 matte RoughMet files retained byte-for-byte from v0.10; albedo untouched.'
$report|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Release/v0.11-Material-Fix/VALIDATION.txt') -Encoding utf8
$report

