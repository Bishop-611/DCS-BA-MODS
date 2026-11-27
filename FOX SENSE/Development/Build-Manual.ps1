param([string]$OutputRoot='',[string]$StageRoot='',[string]$InstallerPath='')
$ErrorActionPreference='Stop'
$base=$PSScriptRoot
$source=Join-Path $base 'Source'
$runtime=Join-Path $base 'Package\Overlay'
if(!$OutputRoot){$OutputRoot=Join-Path $base '../Release/0.10.14'}
$release=[IO.Path]::GetFullPath($OutputRoot)
if(!$StageRoot){$StageRoot=Join-Path $base 'ManualPackage'}
$stage=[IO.Path]::GetFullPath($StageRoot)
if(Test-Path -LiteralPath $stage){throw 'Use a new, empty manual staging directory'}
if(!$InstallerPath){$InstallerPath=Join-Path $base 'F4E FOX SENSE Setup.exe'}
$app=Join-Path $stage 'Saved Games\DCS\Mods\F4E FOX SENSE'
$dest=Join-Path $app 'Runtime\Overlay'
[void][IO.Directory]::CreateDirectory($dest)
Get-ChildItem -LiteralPath $runtime | Copy-Item -Destination $dest -Recurse -Force
[void][IO.Directory]::CreateDirectory((Join-Path $app 'Runtime'))
Copy-Item -LiteralPath (Join-Path $source 'Defaults\HudSettings.json') -Destination (Join-Path $app 'Runtime\HudSettings.json') -Force
foreach($name in @('logo.png','F4E FOX SENSE.ico')){Copy-Item -LiteralPath (Join-Path $source ('Branding\'+$name)) -Destination $app -Force}
$bridge=Join-Path $stage 'Saved Games\DCS\Scripts\F4RwrLink'
[void][IO.Directory]::CreateDirectory($bridge)
Copy-Item -LiteralPath (Join-Path $source 'Bridge\ExportBridge.lua') -Destination $bridge -Force
Copy-Item -LiteralPath (Join-Path $source 'Bridge\FoxBridgeActivity.lua') -Destination $bridge -Force
$hooks=Join-Path $stage 'Saved Games\DCS\Scripts\Hooks'
[void][IO.Directory]::CreateDirectory($hooks)
Copy-Item -LiteralPath (Join-Path $source 'Bridge\FoxViewFov.lua') -Destination $hooks -Force
$jester=Join-Path $stage 'Saved Games\DCS_F4E\jester\mods'
[void][IO.Directory]::CreateDirectory((Join-Path $jester 'init'))
$probe=[IO.File]::ReadAllText((Join-Path $source 'Bridge\F4RwrProbe.lua'))
$probe=$probe.Replace('__FOX_PROBE_LOG__','YOUR_DCS_PROFILE/Logs/F4RwrProbe.log')
[IO.File]::WriteAllText((Join-Path $jester 'F4RwrProbe.lua'),$probe,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $source 'Bridge\StartF4RwrProbe.lua') -Destination (Join-Path $jester 'init') -Force
$start=@'
@echo off
setlocal
for %%I in ("%~dp0..\..") do set "FOX_PROFILE=%%~fI"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%~dp0Runtime\Overlay\Overlay.ps1" -ProfileRoot "%FOX_PROFILE%"
if errorlevel 1 pause
endlocal
'@
[IO.File]::WriteAllText((Join-Path $app 'Start FOX SENSE.cmd'),$start.Replace("`n","`r`n"),[Text.Encoding]::ASCII)
$export=@'
-- Append this block to your existing Saved Games\DCS\Scripts\Export.lua.
-- Do not replace the whole Export.lua. Do not add the block twice.
-- F4RWRLINK_BEGIN
dofile(lfs.writedir() .. [[Scripts/F4RwrLink/ExportBridge.lua]])
-- F4RWRLINK_END
'@
[IO.File]::WriteAllText((Join-Path $stage 'Export.lua.addition.txt'),$export,[Text.UTF8Encoding]::new($false))
$portrait=Join-Path $stage 'Optional Portrait\Mods\aircraft\F-4E\UI\JesterSubtitle\img'
[void][IO.Directory]::CreateDirectory($portrait)
Copy-Item -LiteralPath (Join-Path $source 'Portrait\jester_portrait.png') -Destination $portrait -Force
$readme=@'
FOX SENSE 0.10.14 - Manual installation

Adaptive HUD proportions follow the current DCS window. Text and symbols
remain uniform on ultrawide and other aspect ratios; target centers retain
their full-window projection. The 3440x1440 display fix was confirmed by the user.
Camera/HUD target 60 Hz, world/target snapshots 10 Hz. The bridge
requires a fresh local HUD heartbeat and stops work when FOX SENSE exits.
The Flight data switch independently controls speed, altitude, HDG, AoA, Mach
and G. Actual rendering rate depends on game/render workload.
Restart DCS after installing the GUI hook. Standard single-view desktop
rendering is the intended target; VR and custom multi-camera viewports need
separate validation. If no fresh FOV is available, manual calibration is used.
This update does not claim to resolve the reported head-motion alignment issue.

This package does not require the FOX SENSE Setup EXE. It uses the same runtime
files as the EXE edition. Do not run both editions at the same time.

1. Close DCS and FOX SENSE. Back up any existing FOX SENSE application folder,
   your Saved Games\DCS\Scripts\Export.lua, and any existing F4RwrProbe.lua or
   init\StartF4RwrProbe.lua under Saved Games\DCS_F4E\jester\mods.

2. Copy the CONTENTS of this package's "Saved Games" folder into your Windows
   Saved Games folder.
   Merge the corresponding folders; do not replace an entire profile folder.
   If you use DCS.openbeta or another DCS.* profile, use that folder instead
   of DCS. Keep DCS_F4E\jester\mods at your actual Jester mods location.
   On upgrade, keep your existing Runtime\HudSettings.json to retain settings.

3. IMPORTANT: edit Saved Games\DCS_F4E\jester\mods\F4RwrProbe.lua with a text
   editor. Replace the placeholder YOUR_DCS_PROFILE with the full
   path to YOUR DCS profile folder, leaving /Logs/F4RwrProbe.log after it:
   YOUR_DCS_PROFILE/Logs/F4RwrProbe.log
   If you use DCS.openbeta, use DCS.openbeta in that path. Preserve the [[ ]].

4. Open your DCS profile's Scripts\Export.lua. If it does not exist, create it.
   Append the block from Export.lua.addition.txt, unless the same F4RWRLINK
   block already exists. Preserve all other mods' contents and callbacks.

5. Start DCS and enter the F-4E cockpit. Run:
   Saved Games\DCS\Mods\F4E FOX SENSE\Start FOX SENSE.cmd
   The CMD starts Windows PowerShell using the normal RemoteSigned policy.
   It does not change system execution policy or install a Windows font.
   If Windows marks a downloaded archive as blocked, review its source and
   use Properties > Unblock on the downloaded ZIP before extracting it.
   Organization security restrictions are not bypassed.

OPTIONAL PORTRAIT
   Skip this section to retain the current Jester portrait. To use the supplied
   portrait, first back up the existing file at:
   <DCS GAME>\Mods\aircraft\F-4E\UI\JesterSubtitle\img\jester_portrait.png
   Then copy the corresponding file from "Optional Portrait" into the DCS game
   folder. This affects the subtitle portrait, not the rear-seat 3D model.

REMOVAL / RESTORATION
   Close FOX SENSE and DCS. Remove only the F4RWRLINK block from Export.lua.
   Remove Scripts\Hooks\FoxViewFov.lua only, or restore its prior backup.
   Restore/remove only Scripts\F4RwrLink\FoxBridgeActivity.lua as applicable.
   Restore the two Jester mod files from your backups, or remove those exact
   files if they were newly added. Remove the FOX SENSE application folder.
   If you chose the portrait, restore its original backup. Do not delete other
   mods or replace newer Export.lua edits with an outdated backup.

NOTES
   The HUD visibility shortcut was removed; use the HUD switch in the menu.
   Export data availability depends on the mission/server. Multiplayer IC and
   antivirus compatibility must be checked in your actual environment.
   Font license: Runtime\Overlay\Fonts\OFL.txt inside the application folder.
'@
[IO.File]::WriteAllText((Join-Path $stage 'README.txt'),$readme,[Text.UTF8Encoding]::new($false))
foreach($file in Get-ChildItem -LiteralPath $runtime -Recurse -File){
 $relative=$file.FullName.Substring(([IO.Path]::GetFullPath($runtime)).Length+1)
 if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $dest $relative)).Hash){throw ('Runtime mismatch: '+$relative)}
}
if(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter '*.exe'){throw 'Unexpected executable in manual package'}
[void][IO.Directory]::CreateDirectory($release)
if([IO.Path]::GetFullPath($InstallerPath) -ne (Join-Path $release 'F4E FOX SENSE Setup.exe')){
 Copy-Item -LiteralPath $InstallerPath -Destination (Join-Path $release 'F4E FOX SENSE Setup.exe') -Force
}
$zip=Join-Path $release 'FOX-SENSE-0.10.14-Manual.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal -Force
Get-FileHash -LiteralPath (Join-Path $release 'F4E FOX SENSE Setup.exe'),$zip -Algorithm SHA256 | ForEach-Object {$_.Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($_.Path)} | Set-Content -LiteralPath (Join-Path $release 'SHA256SUMS.txt') -Encoding ASCII
Write-Output 'PASS: manual runtime hashes match EXE payload; no bundled EXE; no personal settings or logs copied'
