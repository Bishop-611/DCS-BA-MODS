[CmdletBinding()]
param([ValidateSet('Install','Restore','Check')][string]$Action='Check',
 [Parameter(Mandatory=$true)][string]$DcsRoot,
 [string]$SavedGames=(Join-Path $env:USERPROFILE 'Saved Games/DCS'),
 [string]$StateHome=(Join-Path $env:LOCALAPPDATA 'F4ModernAvionics/Installations'))
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
$utf8=New-Object Text.UTF8Encoding($false)
function Hash($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
function WriteText($p,$text){[IO.Directory]::CreateDirectory((Split-Path $p))|Out-Null;[IO.File]::WriteAllText($p,$text,$utf8)}
function SaveJson($p,$value){WriteText $p ($value|ConvertTo-Json -Depth 12)}
function Full($p){[IO.Path]::GetFullPath($p).TrimEnd('\','/')}
$DcsRoot=Full $DcsRoot;$SavedGames=Full $SavedGames;$StateHome=Full $StateHome
if($StateHome.StartsWith($DcsRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or $StateHome -eq $DcsRoot){throw 'Runtime files and backups must be outside the DCS game directory.'}
$sha=[Security.Cryptography.SHA256]::Create()
$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($DcsRoot+'|'+$SavedGames).ToLowerInvariant())))).Replace('-','').Substring(0,20)
$sha.Dispose()
$installHome=Join-Path $StateHome $key;$statePath=Join-Path $installHome 'installed.json'
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw|ConvertFrom-Json
function CheckEntries($state,[switch]$Restoring){
 if($state.dcsRoot -ne $DcsRoot -or $state.savedGames -ne $SavedGames){throw 'Installation record does not match the selected paths.'}
 foreach($e in $state.entries){
  $target=Full $e.target;$backup=Full $e.backup
  if((-not $target.StartsWith($DcsRoot+'\',[StringComparison]::OrdinalIgnoreCase) -and -not $target.StartsWith($SavedGames+'\',[StringComparison]::OrdinalIgnoreCase)) -or -not $backup.StartsWith($installHome+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Installation record contains out-of-bounds paths.'}
  if($e.existed -and (-not(Test-Path -LiteralPath $e.backup) -or (Hash $e.backup) -ne $e.sourceHash)){throw "Original backup is damaged: $($e.target)"}
  if(Test-Path -LiteralPath $e.target){
   $h=Hash $e.target
   if($h -ne $e.stageHash -and (-not $Restoring -or -not $e.existed -or $h -ne $e.sourceHash)){throw "File changed after installation; stopped to preserve later edits: $($e.target)"}
  }elseif(-not $Restoring -or $e.existed){throw "Installed file is missing: $($e.target)"}
 }
}
function RestoreEntries($state){
 CheckEntries $state -Restoring
 foreach($e in $state.entries){
  if($e.existed){Copy-Item -LiteralPath $e.backup -Destination $e.target -Force;if((Hash $e.target) -ne $e.sourceHash){throw 'Hash mismatch after restoration.'}}
  elseif(Test-Path -LiteralPath $e.target){Remove-Item -LiteralPath $e.target}
 }
 $state.status='restored';SaveJson $statePath $state
 Move-Item -LiteralPath $statePath -Destination (Join-Path $installHome ('restored-'+[guid]::NewGuid().ToString('N')+'.json'))
}
if($Action -eq 'Check'){
 if(Test-Path -LiteralPath $statePath){$state=Get-Content $statePath -Raw|ConvertFrom-Json;CheckEntries $state;'Installed. All target files and original backups verified.';"Runtime: $($state.runtime)"}
 else{'This package is not installed at the selected paths.'}
 "Backup location: $installHome";return
}
if(Get-Process DCS -ErrorAction SilentlyContinue){throw 'Fully exit DCS before installing or restoring.'}
if($Action -eq 'Restore'){
 if(-not(Test-Path -LiteralPath $statePath)){'This package is not installed at the selected paths; nothing to restore.';return}
 $state=Get-Content $statePath -Raw|ConvertFrom-Json
 RestoreEntries $state
 'Pre-installation files fully restored. Backups are retained outside the game directory.';return
}
if(Test-Path -LiteralPath $statePath){
 $state=Get-Content $statePath -Raw|ConvertFrom-Json;CheckEntries $state
 if($state.version -ne $manifest.version){throw 'A different package version is installed. Click Restore, then Install to apply this version.'}
 if($state.status -eq 'installed'){'Already installed and verified; no reinstall needed.';return}
 throw 'An incomplete installation was detected. Click Restore first.'
}
if(-not(Test-Path -LiteralPath (Join-Path $DcsRoot 'Mods/aircraft/F-4E/Cockpit/device_init.lua'))){throw 'The selected folder is not a DCS installation root containing the F-4E.'}
$version=(Get-Content -LiteralPath (Join-Path $DcsRoot 'autoupdate.cfg') -Raw|ConvertFrom-Json).version
if($version -ne $manifest.dcsVersion){throw "This package supports DCS $($manifest.dcsVersion); the selected version is $version. Stopped without changing the game."}
foreach($f in $manifest.files){if((Hash (Join-Path $PSScriptRoot $f.path)) -ne $f.hash){throw "Payload verification failed: $($f.path)"}}
foreach($f in $manifest.baseline){
 $p=Join-Path $DcsRoot $f.path
 if(-not(Test-Path -LiteralPath $p) -or (Hash $p) -ne $f.hash){throw "Game file mismatch or existing modification: $($f.path). Restore other cockpit modifications first."}
}
$session=Join-Path $installHome ('session-'+[guid]::NewGuid().ToString('N'))
$runtime=Join-Path $session 'Runtime/SimpleAvionics'
if($runtime.Contains(']]')){throw 'Runtime directory contains unsupported Lua path characters.'}
[IO.Directory]::CreateDirectory($runtime)|Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'Runtime/SimpleAvionics/*') -Destination $runtime -Recurse
$luaRoot=$runtime.Replace('\','/')
foreach($file in Get-ChildItem -LiteralPath $runtime -Recurse -File -Filter '*.lua'){
 $text=[IO.File]::ReadAllText($file.FullName).Replace('__F4_RUNTIME__',$luaRoot)
 WriteText $file.FullName $text
}
$entries=New-Object 'System.Collections.Generic.List[object]'
function Stage($target,$text,$binary){
 $i=$entries.Count;$stage=Join-Path $session "Staged/$i.bin";$backup=Join-Path $session "Backup/$i.before"
 [IO.Directory]::CreateDirectory((Split-Path $stage))|Out-Null
 if($binary){Copy-Item -LiteralPath $binary -Destination $stage}else{WriteText $stage $text}
 $existed=Test-Path -LiteralPath $target
 $entries.Add([pscustomobject]@{target=$target;stage=$stage;stageHash=(Hash $stage);backup=$backup;existed=[bool]$existed;sourceHash=$(if($existed){Hash $target}else{$null})})
}
$cockpit=Join-Path $DcsRoot 'Mods/aircraft/F-4E/Cockpit'
$entry=Join-Path $cockpit 'device_init.lua';$text=[IO.File]::ReadAllText($entry)
if($text -match 'F4_SIMPLE_|F4ModernHUD'){throw 'Another experimental cockpit entry was detected. Restore it first.'}
$hudOld='LockOn_Options.script_path.."Scripts/HeadUpDisplay/Indicator/init.lua"'
$radarOld='"F4EAvionics::ccRadar", LockOn_Options.script_path.."Scripts/DSCG/indicator/init.lua"'
foreach($old in @($hudOld,$radarOld)){if([regex]::Matches($text,[regex]::Escape($old)).Count -ne 1){throw 'Native cockpit structure does not match the supported version.'}}
if($text -match 'creators\[20[01345]\]'){throw 'Avionics device IDs are already in use.'}
$text=$text.Replace($hudOld,"[[$luaRoot/HUD/init.lua]]").Replace($radarOld,('"F4EAvionics::ccRadar", [['+$luaRoot+'/Controls/display-cockpit-init.lua]]'))
$text+=@"

-- F4_SIMPLE_MODERN_AVIONICS: radar + HUD (CCIP included), native RWR unchanged.
creators[200] = {"avSimpleElectricSystem", [[$luaRoot/electric.lua]]}
creators[201] = {"avSimpleRadar", [[$luaRoot/Controls/radar-manual.lua]]}
creators[203] = {"avLuaDevice", [[$luaRoot/Controls/input-device.lua]]}
creators[204] = {"avLuaDevice", [[$luaRoot/Controls/block-original-radar.lua]]}
creators[205] = {"avLuaDevice", [[$luaRoot/HUD/device.lua]]}
"@
Stage $entry $text $null
$path=Join-Path $cockpit 'clickabledata.lua'
Stage $path ([IO.File]::ReadAllText($path)+"`n-- F4_SIMPLE_CLICKABLE_ROUTER`ndofile([[$luaRoot/Controls/clickable-router.lua]])(elements)`n") $null
foreach($inputFile in @($manifest.baseline | Where-Object {$_.path -like 'Mods/aircraft/F-4E/Input/F-4E-Pilot/*/*.lua'})){
 $path=Join-Path $DcsRoot $inputFile.path
 $text=[IO.File]::ReadAllText($path)
 if([regex]::Matches($text,'(?m)^return res\s*$').Count -ne 1){throw "Unsupported input file format: $($inputFile.path)"}
 Stage $path ([regex]::Replace($text,'(?m)^return res\s*$',"return dofile([[$luaRoot/Controls/route-profile.lua]])(res)")) $null
}
Stage (Join-Path $DcsRoot 'Mods/aircraft/F-4E/fxo/DSCG.fxo') $null (Join-Path $runtime 'DSCG.fxo')
$export=Join-Path $SavedGames 'Scripts/Export.lua'
$text=if(Test-Path -LiteralPath $export){[IO.File]::ReadAllText($export)}else{''}
if($text.Contains('F4_SIMPLE_CCIP_EXPORT')){throw 'An unmanaged CCIP export hook already exists.'}
Stage $export ($text+"`n-- F4_SIMPLE_CCIP_EXPORT`ndofile([[$luaRoot/HUD/CCIP/export.lua]])`n") $null
$inputRoot=Join-Path $SavedGames 'Config/Input/F-4E-45MC'
if(Test-Path -LiteralPath $inputRoot){
 foreach($file in Get-ChildItem -LiteralPath $inputRoot -Recurse -File -Filter '*.diff.lua'){
  $text=[IO.File]::ReadAllText($file.FullName);$next=$text
  foreach($line in Get-Content -LiteralPath (Join-Path $runtime 'Controls/input-hash-map.tsv')){
   $pair=$line -split "`t";if($pair.Count -ne 2){throw 'Invalid binding migration table.'}
   $old='["'+$pair[0]+'"]';$new='["'+$pair[1]+'"]'
   if($text.Contains($old)){
    if($text.Contains($new)){throw "Binding migration conflict: $($file.Name)"}
    $next=$next.Replace($old,$new)
   }
  }
  if($next -ne $text){Stage $file.FullName $next $null}
 }
}
# Complete all staging and original backups before the first target mutation.
foreach($e in $entries){
 if($e.existed){
  if((Hash $e.target) -ne $e.sourceHash){throw 'A target file changed during preparation.'}
  [IO.Directory]::CreateDirectory((Split-Path $e.backup))|Out-Null
  Copy-Item -LiteralPath $e.target -Destination $e.backup
  if((Hash $e.backup) -ne $e.sourceHash){throw 'Original backup verification failed.'}
 }
}
$state=[pscustomobject]@{status='installing';version=$manifest.version;dcsRoot=$DcsRoot;savedGames=$SavedGames;runtime=$runtime;entries=@($entries.ToArray())}
SaveJson $statePath $state
try{
 foreach($e in $entries){
  [IO.Directory]::CreateDirectory((Split-Path $e.target))|Out-Null
  Copy-Item -LiteralPath $e.stage -Destination $e.target -Force
  if((Hash $e.target) -ne $e.stageHash){throw 'Post-installation verification failed.'}
 }
 $state.status='installed';SaveJson $statePath $state
 'Installation complete: radar + HUD (including CCIP). Native RWR retained.'
 "Runtime files and backups: $session"
}catch{
 $reason=$_.Exception.Message
 $rollbackError=$null
 try{RestoreEntries $state}catch{$rollbackError=$_.Exception.Message}
 if($rollbackError){throw "Installation incomplete. Click Restore. Cause: $reason; rollback details: $rollbackError"}
 throw "Installation failed; automatically restored: $reason"
}
