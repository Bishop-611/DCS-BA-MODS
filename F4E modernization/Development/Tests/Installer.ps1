param([string]$BaselineRoot='D:/DCS/DCS World')
$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path $PSScriptRoot)
$test=Join-Path $PSScriptRoot ('Run-'+[guid]::NewGuid().ToString('N'))
$payload=Join-Path $test 'Extracted'
$p=Start-Process -FilePath (Join-Path $project 'F4E-Modern-Avionics.exe') -ArgumentList @('--extract-to',('"'+$payload+'"')) -Wait -PassThru
if($p.ExitCode){throw 'EXE extraction failed'}
$manifest=Get-Content (Join-Path $payload 'manifest.json') -Raw|ConvertFrom-Json
$game=Join-Path $test 'DCS';$saved=Join-Path $test 'Saved';$state=Join-Path $test 'State'
foreach($f in $manifest.baseline){$dest=Join-Path $game $f.path;[IO.Directory]::CreateDirectory((Split-Path $dest))|Out-Null;Copy-Item -LiteralPath (Join-Path $BaselineRoot $f.path) -Destination $dest;if((Get-FileHash $dest).Hash -ne $f.hash){throw 'Test fixture does not match the pinned native baseline.'}}
[IO.File]::WriteAllText((Join-Path $game 'autoupdate.cfg'),('{"version":"'+$manifest.dcsVersion+'"}'))
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
if(-not([IO.File]::ReadAllText($binding).Contains($map[1]))){throw 'Binding migration failed'}
$entry=Join-Path $game 'Mods/aircraft/F-4E/Cockpit/device_init.lua'
if([IO.File]::ReadAllText($entry) -match 'creators\[202\]'){throw 'Simple RWR must not be installed'}
Run Install;Run Check
if((Get-FileHash $receipt.FullName).Hash -ne $receiptHash){throw 'Repeated installation changed backup state'}
$installed=[IO.File]::ReadAllBytes($export);[IO.File]::AppendAllText($export,'-- later modification')
$entryHash=(Get-FileHash $entry).Hash
Run Restore 1
if((Get-FileHash $entry).Hash -ne $entryHash){throw 'Restore preflight failure caused partial writes'}
[IO.File]::WriteAllBytes($export,$installed)
Run Restore
foreach($path in $original.Keys){if((Get-FileHash $path).Hash -ne $original[$path]){throw "Exact restoration failed: $path"}}
Run Restore
# Originally absent Export must disappear after restore.
Remove-Item -LiteralPath $export
Run Install;Run Restore
if(Test-Path $export){throw 'Originally absent Export was not removed'}
# Wrong version must fail without writing native files.
[IO.File]::WriteAllText((Join-Path $game 'autoupdate.cfg'),'{"version":"0.0"}')
Run Install 1
foreach($f in $manifest.baseline){if((Get-FileHash (Join-Path $game $f.path)).Hash -ne $f.hash){throw 'Version rejection changed native files'}}
"PASS: EXE extraction; Windows PowerShell 5.1 install/check/idempotence; binding migration; conflict preflight; exact restore; absent Export; version guard. Test directory: $test"
