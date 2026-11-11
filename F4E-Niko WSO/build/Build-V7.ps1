param([string]$BasePayload='', [string]$BaseExe='', [string]$LiveryRoot='', [string]$OutputRoot='', [string]$TempUpgradeRoot='', [switch]$GenerateLivery)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
if(-not $OutputRoot){$OutputRoot=Join-Path (Split-Path $PSScriptRoot) 'Release/v7'}
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
[IO.Directory]::CreateDirectory($OutputRoot)|Out-Null
$work=Join-Path ([IO.Path]::GetTempPath()) ('F4-Niko-v7-build-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work)|Out-Null
function HashFile($path){$h=[Security.Cryptography.SHA256]::Create();$s=[IO.File]::OpenRead($path);try{return ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$s.Dispose();$h.Dispose()}}
$assembly=$null
if($BaseExe){$assembly=[Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($BaseExe))}
if(-not $BasePayload){
 if(-not $assembly){throw 'Supply BasePayload or BaseExe.'}
 $BasePayload=Join-Path $work 'v6-payload.zip'
 $src=$assembly.GetManifestResourceStream('payload.zip');$dst=[IO.File]::Create($BasePayload)
 try{$src.CopyTo($dst)}finally{$src.Dispose();$dst.Dispose()}
}
$base=[IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($BasePayload))
try{
 $reader=New-Object IO.StreamReader($base.GetEntry('manifest.json').Open())
 try{$items=ConvertFrom-Json -InputObject ($reader.ReadToEnd())}finally{$reader.Dispose()}
 $prefix='after/SavedGames/Liveries/F-4E-45MC/F4E-FOX PLATOON/'
 if($GenerateLivery){
  $LiveryRoot=Join-Path $work 'Livery'
  $original=Join-Path $LiveryRoot 'package-fox-platoon/Liveries/F-4E-45MC/F4E-FOX PLATOON'
  [IO.Directory]::CreateDirectory($original)|Out-Null
  foreach($entry in $base.Entries|Where-Object {$_.FullName.StartsWith($prefix,[StringComparison]::Ordinal)}){
   [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $original ([IO.Path]::GetFileName($entry.FullName))))
  }
  foreach($name in @('Build-Matte.ps1','Build-MaterialFix.ps1','Build-DarkWeathered.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $LiveryRoot $name)}
  $ps=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
  & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $LiveryRoot 'Build-Matte.ps1')
  if($LASTEXITCODE){throw 'Matte texture generation failed.'}
  & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $LiveryRoot 'Build-MaterialFix.ps1')
  if($LASTEXITCODE){throw 'Normal header generation failed.'}
  & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $LiveryRoot 'Build-DarkWeathered.ps1') -Revision v0.13-Deep-Detail -Darken 0.18 -DetailContrast 0.10 -NormalStrength 1.30 -EdgeLight 0.025
  if($LASTEXITCODE){throw 'Paint texture generation failed.'}
 }
 if(-not $LiveryRoot){throw 'Supply LiveryRoot or GenerateLivery.'}
 $overrides=@{}
 foreach($f in Get-ChildItem -LiteralPath (Join-Path $LiveryRoot 'Release/v0.13-Deep-Detail/Liveries/F-4E-45MC/F4E-FOX PLATOON') -File -Filter '*.dds'){$overrides[$f.Name]=$f.FullName}
 foreach($f in Get-ChildItem -LiteralPath (Join-Path $LiveryRoot 'Release/v0.11-Material-Fix/Liveries/F-4E-45MC/F4E-FOX PLATOON') -File -Filter '*_RoughMet.dds'){$overrides[$f.Name]=$f.FullName}
 if($overrides.Count -ne 33){throw 'The v0.13 livery needs 33 DDS textures.'}
 $history=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'livery-history.json') -Raw|ConvertFrom-Json
 foreach($item in $items){
  $name=[IO.Path]::GetFileName($item.path)
  if($item.scope -eq 'saved' -and $item.path.Replace('\','/').StartsWith('Liveries/F-4E-45MC/F4E-FOX PLATOON/') -and $overrides.ContainsKey($name)){
   $accepted=@($item.after)+@($item.accepted)+@($history.PSObject.Properties[$name].Value)
   $item|Add-Member -NotePropertyName accepted -NotePropertyValue @($accepted|Where-Object {$_}|Select-Object -Unique) -Force
   $item|Add-Member -NotePropertyName after -NotePropertyValue (HashFile $overrides[$name]) -Force
  }
 }
 $payload=Join-Path $OutputRoot 'payload.zip'
 if(Test-Path -LiteralPath $payload){throw 'Output payload already exists; choose a new output directory.'}
 $next=[IO.Compression.ZipFile]::Open($payload,[IO.Compression.ZipArchiveMode]::Create)
 try{
  $i=0
  foreach($entry in $base.Entries){
   if($entry.FullName -eq 'manifest.json'){continue}
   $name=[IO.Path]::GetFileName($entry.FullName)
   if($entry.FullName.StartsWith($prefix,[StringComparison]::Ordinal) -and $overrides.ContainsKey($name)){
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($next,$overrides[$name],$entry.FullName,[IO.Compression.CompressionLevel]::Optimal)|Out-Null
   }else{
    $e=$next.CreateEntry($entry.FullName,[IO.Compression.CompressionLevel]::Fastest)
    $src=$entry.Open();$dst=$e.Open();try{$src.CopyTo($dst)}finally{$src.Dispose();$dst.Dispose()}
   }
   $i++;if($i%2000 -eq 0){"Packing $i / $($base.Entries.Count)"}
  }
  $e=$next.CreateEntry('manifest.json');$writer=New-Object IO.StreamWriter($e.Open())
  try{$writer.Write(($items|ConvertTo-Json -Depth 12 -Compress))}finally{$writer.Dispose()}
 }finally{$next.Dispose()}
 $assets=Join-Path $work 'Assets';[IO.Directory]::CreateDirectory($assets)|Out-Null
 $background=Join-Path $assets 'background.png'
 if($assembly){$s=$assembly.GetManifestResourceStream('background.png');$d=[IO.File]::Create($background);try{$s.CopyTo($d)}finally{$s.Dispose();$d.Dispose()}}
 else{Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot) 'Build/BundleAssets/background.png') -Destination $background}
 $icon=Join-Path $PSScriptRoot 'niko-icon.ico'
 if(-not(Test-Path -LiteralPath $icon)){$icon=Join-Path (Split-Path $PSScriptRoot) 'Build/BundleAssets/niko-icon.ico'}
 $manifest=Join-Path $work 'app.manifest'
 [IO.File]::WriteAllText($manifest,'<?xml version="1.0" encoding="utf-8"?><assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security></trustInfo></assembly>')
 $compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
 function Compile($zip,$exe,$delta){
  $args=@('/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$exe),('/win32manifest:'+$manifest),('/win32icon:'+$icon),('/resource:'+$zip+',payload.zip'),('/resource:'+$background+',background.png'),'/r:System.Windows.Forms.dll','/r:System.Drawing.dll','/r:System.Web.Extensions.dll','/r:System.IO.Compression.dll')
  if($delta){$flag=Join-Path $work 'livery-only.txt';[IO.File]::WriteAllText($flag,'temporary');$args+=('/resource:'+$flag+',livery-only')}
  $args+=(Join-Path $PSScriptRoot 'NikoInstaller.cs')
  & $compiler @args
  if($LASTEXITCODE){throw 'Installer compilation failed.'}
 }
 $exe=Join-Path $OutputRoot 'F4E-Niko-WSO-v7.exe'
 Compile $payload $exe $false
 [IO.File]::WriteAllText((Join-Path $OutputRoot 'F4E-Niko-WSO-v7.sha256'),(HashFile $exe)+'  F4E-Niko-WSO-v7.exe'+[Environment]::NewLine)
 "BUILT $exe"
 if($TempUpgradeRoot){
  [IO.Directory]::CreateDirectory($TempUpgradeRoot)|Out-Null
  $deltaZip=Join-Path $work 'temporary-livery.zip'
  $delta=[IO.Compression.ZipFile]::Open($deltaZip,[IO.Compression.ZipArchiveMode]::Create)
  $livery=@($items|Where-Object {$_.scope -eq 'saved' -and $_.path.Replace('\','/').StartsWith('Liveries/F-4E-45MC/F4E-FOX PLATOON/')})
  try{
   foreach($f in $livery){$name=[IO.Path]::GetFileName($f.path);$rel=$prefix+$name
    if($overrides.ContainsKey($name)){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($delta,$overrides[$name],$rel,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}
    else{$src=$base.GetEntry($rel).Open();$dst=$delta.CreateEntry($rel).Open();try{$src.CopyTo($dst)}finally{$src.Dispose();$dst.Dispose()}}
   }
   $w=New-Object IO.StreamWriter($delta.CreateEntry('manifest.json').Open());try{$w.Write(($livery|ConvertTo-Json -Depth 12 -Compress))}finally{$w.Dispose()}
  }finally{$delta.Dispose()}
  $deltaExe=Join-Path $TempUpgradeRoot 'FOX-PLATOON-v0.13-Temporary-Upgrade.exe'
  Compile $deltaZip $deltaExe $true
  "TEMPORARY $deltaExe"
 }
}finally{$base.Dispose()}

