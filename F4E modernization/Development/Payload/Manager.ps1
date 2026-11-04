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
if($StateHome.StartsWith($DcsRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or $StateHome -eq $DcsRoot){throw '运行文件和备份必须放在 DCS 游戏目录之外。'}
$sha=[Security.Cryptography.SHA256]::Create()
$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($DcsRoot+'|'+$SavedGames).ToLowerInvariant())))).Replace('-','').Substring(0,20)
$sha.Dispose()
$installHome=Join-Path $StateHome $key;$statePath=Join-Path $installHome 'installed.json'
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw|ConvertFrom-Json
function CheckEntries($state,[switch]$Restoring){
 if($state.dcsRoot -ne $DcsRoot -or $state.savedGames -ne $SavedGames){throw '安装记录与所选路径不一致。'}
 foreach($e in $state.entries){
  $target=Full $e.target;$backup=Full $e.backup
  if((-not $target.StartsWith($DcsRoot+'\',[StringComparison]::OrdinalIgnoreCase) -and -not $target.StartsWith($SavedGames+'\',[StringComparison]::OrdinalIgnoreCase)) -or -not $backup.StartsWith($installHome+'\',[StringComparison]::OrdinalIgnoreCase)){throw '安装记录包含越界路径。'}
  if($e.existed -and (-not(Test-Path -LiteralPath $e.backup) -or (Hash $e.backup) -ne $e.sourceHash)){throw "原始备份损坏：$($e.target)"}
  if(Test-Path -LiteralPath $e.target){
   $h=Hash $e.target
   if($h -ne $e.stageHash -and (-not $Restoring -or -not $e.existed -or $h -ne $e.sourceHash)){throw "文件在安装后发生变化，已停止以保护修改：$($e.target)"}
  }elseif(-not $Restoring -or $e.existed){throw "已安装文件缺失：$($e.target)"}
 }
}
function RestoreEntries($state){
 CheckEntries $state -Restoring
 foreach($e in $state.entries){
  if($e.existed){Copy-Item -LiteralPath $e.backup -Destination $e.target -Force;if((Hash $e.target) -ne $e.sourceHash){throw '还原后哈希不一致。'}}
  elseif(Test-Path -LiteralPath $e.target){Remove-Item -LiteralPath $e.target}
 }
 $state.status='restored';SaveJson $statePath $state
 Move-Item -LiteralPath $statePath -Destination (Join-Path $installHome ('restored-'+[guid]::NewGuid().ToString('N')+'.json'))
}
if($Action -eq 'Check'){
 if(Test-Path -LiteralPath $statePath){$state=Get-Content $statePath -Raw|ConvertFrom-Json;CheckEntries $state;'已安装，全部目标文件与原始备份核对通过。';"运行文件：$($state.runtime)"}
 else{'当前路径未安装本整合包。'}
 "备份位置：$installHome";return
}
if(Get-Process DCS -ErrorAction SilentlyContinue){throw '请完全退出 DCS 后再安装或还原。'}
if($Action -eq 'Restore'){
 if(-not(Test-Path -LiteralPath $statePath)){'当前路径未安装本整合包，无需还原。';return}
 $state=Get-Content $statePath -Raw|ConvertFrom-Json
 RestoreEntries $state
 '已完整还原安装前文件。备份保留在游戏目录之外。';return
}
if(Test-Path -LiteralPath $statePath){
 $state=Get-Content $statePath -Raw|ConvertFrom-Json;CheckEntries $state
 if($state.status -eq 'installed'){'已安装，文件核对通过，无需重复安装。';return}
 throw '检测到未完成的安装，请先点击一键还原。'
}
if(-not(Test-Path -LiteralPath (Join-Path $DcsRoot 'Mods/aircraft/F-4E/Cockpit/device_init.lua'))){throw '所选目录不是含 F-4E 的 DCS 安装根目录。'}
$version=(Get-Content -LiteralPath (Join-Path $DcsRoot 'autoupdate.cfg') -Raw|ConvertFrom-Json).version
if($version -ne $manifest.dcsVersion){throw "本包适配 DCS $($manifest.dcsVersion)，当前为 $version。已停止，未改动游戏。"}
foreach($f in $manifest.files){if((Hash (Join-Path $PSScriptRoot $f.path)) -ne $f.hash){throw "安装源校验失败：$($f.path)"}}
foreach($f in $manifest.baseline){
 $p=Join-Path $DcsRoot $f.path
 if(-not(Test-Path -LiteralPath $p) -or (Hash $p) -ne $f.hash){throw "游戏文件不匹配或已有其他修改：$($f.path)。请先还原其他座舱修改。"}
}
$session=Join-Path $installHome ('session-'+[guid]::NewGuid().ToString('N'))
$runtime=Join-Path $session 'Runtime/SimpleAvionics'
if($runtime.Contains(']]')){throw '运行目录包含不支持的 Lua 路径字符。'}
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
if($text -match 'F4_SIMPLE_|F4ModernHUD'){throw '检测到其他实验版入口，请先还原。'}
$hudOld='LockOn_Options.script_path.."Scripts/HeadUpDisplay/Indicator/init.lua"'
$radarOld='"F4EAvionics::ccRadar", LockOn_Options.script_path.."Scripts/DSCG/indicator/init.lua"'
foreach($old in @($hudOld,$radarOld)){if([regex]::Matches($text,[regex]::Escape($old)).Count -ne 1){throw '原装座舱结构与支持版本不一致。'}}
if($text -match 'creators\[20[01345]\]'){throw '航电设备编号已被占用。'}
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
foreach($kind in @('keyboard','joystick')){
 $path=Join-Path $DcsRoot "Mods/aircraft/F-4E/Input/F-4E-Pilot/$kind/default.lua"
 $text=[IO.File]::ReadAllText($path)
 if([regex]::Matches($text,'(?m)^return res\s*$').Count -ne 1){throw "不支持的 $kind 输入文件格式。"}
 Stage $path ([regex]::Replace($text,'(?m)^return res\s*$',"return dofile([[$luaRoot/Controls/route-profile.lua]])(res)")) $null
}
Stage (Join-Path $DcsRoot 'Mods/aircraft/F-4E/fxo/DSCG.fxo') $null (Join-Path $runtime 'DSCG.fxo')
$export=Join-Path $SavedGames 'Scripts/Export.lua'
$text=if(Test-Path -LiteralPath $export){[IO.File]::ReadAllText($export)}else{''}
if($text.Contains('F4_SIMPLE_CCIP_EXPORT')){throw '存在未受本包管理的 CCIP 钩子。'}
Stage $export ($text+"`n-- F4_SIMPLE_CCIP_EXPORT`ndofile([[$luaRoot/HUD/CCIP/export.lua]])`n") $null
$inputRoot=Join-Path $SavedGames 'Config/Input/F-4E-45MC'
if(Test-Path -LiteralPath $inputRoot){
 foreach($file in Get-ChildItem -LiteralPath $inputRoot -Recurse -File -Filter '*.diff.lua'){
  $text=[IO.File]::ReadAllText($file.FullName);$next=$text
  foreach($line in Get-Content -LiteralPath (Join-Path $runtime 'Controls/input-hash-map.tsv')){
   $pair=$line -split "`t";if($pair.Count -ne 2){throw '键位迁移表无效。'}
   $old='["'+$pair[0]+'"]';$new='["'+$pair[1]+'"]'
   if($text.Contains($old)){
    if($text.Contains($new)){throw "键位迁移发生冲突：$($file.Name)"}
    $next=$next.Replace($old,$new)
   }
  }
  if($next -ne $text){Stage $file.FullName $next $null}
 }
}
# Complete all staging and original backups before the first target mutation.
foreach($e in $entries){
 if($e.existed){
  if((Hash $e.target) -ne $e.sourceHash){throw '准备期间目标发生变化。'}
  [IO.Directory]::CreateDirectory((Split-Path $e.backup))|Out-Null
  Copy-Item -LiteralPath $e.target -Destination $e.backup
  if((Hash $e.backup) -ne $e.sourceHash){throw '原始备份校验失败。'}
 }
}
$state=[pscustomobject]@{status='installing';version=$manifest.version;dcsRoot=$DcsRoot;savedGames=$SavedGames;runtime=$runtime;entries=@($entries.ToArray())}
SaveJson $statePath $state
try{
 foreach($e in $entries){
  [IO.Directory]::CreateDirectory((Split-Path $e.target))|Out-Null
  Copy-Item -LiteralPath $e.stage -Destination $e.target -Force
  if((Hash $e.target) -ne $e.stageHash){throw '安装后校验失败。'}
 }
 $state.status='installed';SaveJson $statePath $state
 '安装成功：雷达 + HUD（含 CCIP）。原装 RWR 保持原样。'
 "运行文件及备份：$session"
}catch{
 $reason=$_.Exception.Message
 $rollbackError=$null
 try{RestoreEntries $state}catch{$rollbackError=$_.Exception.Message}
 if($rollbackError){throw "安装未完成，请点击一键还原。原因：$reason；还原信息：$rollbackError"}
 throw "安装失败，已自动还原：$reason"
}
