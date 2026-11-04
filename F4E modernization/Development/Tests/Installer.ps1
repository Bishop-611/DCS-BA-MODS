$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path $PSScriptRoot)
$test=Join-Path $PSScriptRoot ('Run-'+[guid]::NewGuid().ToString('N'))
$payload=Join-Path $test 'Extracted'
$p=Start-Process -FilePath (Join-Path $project 'F4E-Modern-Avionics.exe') -ArgumentList @('--extract-to',('"'+$payload+'"')) -Wait -PassThru
if($p.ExitCode){throw 'EXE 解包失败'}
$manifest=Get-Content (Join-Path $payload 'manifest.json') -Raw|ConvertFrom-Json
$game=Join-Path $test 'DCS';$saved=Join-Path $test 'Saved';$state=Join-Path $test 'State'
foreach($f in $manifest.baseline){$dest=Join-Path $game $f.path;[IO.Directory]::CreateDirectory((Split-Path $dest))|Out-Null;Copy-Item -LiteralPath (Join-Path 'D:/DCS/DCS World' $f.path) -Destination $dest}
Copy-Item -LiteralPath 'D:/DCS/DCS World/autoupdate.cfg' -Destination $game
$export=Join-Path $saved 'Scripts/Export.lua';[IO.Directory]::CreateDirectory((Split-Path $export))|Out-Null
[IO.File]::WriteAllText($export,'-- unrelated export hook remains unchanged')
$map=(Get-Content (Join-Path $payload 'Runtime/SimpleAvionics/Controls/input-hash-map.tsv') -First 1) -split "`t"
$binding=Join-Path $saved 'Config/Input/F-4E-45MC/joystick/fixture.diff.lua'
[IO.Directory]::CreateDirectory((Split-Path $binding))|Out-Null
[IO.File]::WriteAllText($binding,('return {["'+$map[0]+'"]={name="original option"},["unrelated"]={}}'))
$original=@{};Get-ChildItem $game,$saved -Recurse -File|ForEach-Object{$original[$_.FullName]=(Get-FileHash $_.FullName).Hash}
$ps='C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
function Run($action,$expect=0){
 $output=& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $payload 'Manager.ps1') -Action $action -DcsRoot $game -SavedGames $saved -StateHome $state 2>&1
 if(($expect -eq 0 -and $LASTEXITCODE -ne 0) -or ($expect -ne 0 -and $LASTEXITCODE -eq 0)){throw "$action unexpected result: $output"}
}
Run Install
$receipt=Get-ChildItem $state -Recurse -Filter installed.json|Select-Object -First 1
$receiptHash=(Get-FileHash $receipt.FullName).Hash
if(-not([IO.File]::ReadAllText($binding).Contains($map[1]))){throw '绑定迁移失败'}
$entry=Join-Path $game 'Mods/aircraft/F-4E/Cockpit/device_init.lua'
if([IO.File]::ReadAllText($entry) -match 'creators\[202\]'){throw '不应安装 Simple RWR'}
Run Install;Run Check
if((Get-FileHash $receipt.FullName).Hash -ne $receiptHash){throw '重复安装改变了备份状态'}
$installed=[IO.File]::ReadAllBytes($export);[IO.File]::AppendAllText($export,'-- later modification')
$entryHash=(Get-FileHash $entry).Hash
Run Restore 1
if((Get-FileHash $entry).Hash -ne $entryHash){throw '还原预检失败后发生了部分写入'}
[IO.File]::WriteAllBytes($export,$installed)
Run Restore
foreach($path in $original.Keys){if((Get-FileHash $path).Hash -ne $original[$path]){throw "完整还原失败: $path"}}
Run Restore
# Originally absent Export must disappear after restore.
Remove-Item -LiteralPath $export
Run Install;Run Restore
if(Test-Path $export){throw '原本不存在的 Export 未移除'}
# Wrong version must fail without writing native files.
[IO.File]::WriteAllText((Join-Path $game 'autoupdate.cfg'),'{"version":"0.0"}')
Run Install 1
foreach($f in $manifest.baseline){if((Get-FileHash (Join-Path $game $f.path)).Hash -ne $f.hash){throw '版本拒绝后原文件变化'}}
"PASS: EXE extraction; Windows PowerShell 5.1 install/check/idempotence; binding migration; conflict preflight; exact restore; absent Export; version guard. Test directory: $test"
