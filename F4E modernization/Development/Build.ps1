$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$payload=Join-Path $PSScriptRoot 'Payload'
$game='D:/DCS/DCS World'
$paths=@('Mods/aircraft/F-4E/Cockpit/device_init.lua','Mods/aircraft/F-4E/Cockpit/clickabledata.lua','Mods/aircraft/F-4E/Input/F-4E-Pilot/keyboard/default.lua','Mods/aircraft/F-4E/Input/F-4E-Pilot/joystick/default.lua','Mods/aircraft/F-4E/fxo/DSCG.fxo')
$baseline=(Get-Content -LiteralPath (Join-Path $payload 'manifest.json') -Raw|ConvertFrom-Json).baseline
$files=@(Get-ChildItem $payload -Recurse -File | Where-Object Name -ne 'manifest.json' | ForEach-Object {@{path=$_.FullName.Substring($payload.Length+1).Replace('\','/');hash=(Get-FileHash -LiteralPath $_.FullName).Hash}})
$manifest=@{version='1.0.1';dcsVersion='2.9.31.29434';files=$files;baseline=$baseline}|ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $payload 'manifest.json'),$manifest,(New-Object Text.UTF8Encoding($false)))
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=Join-Path $PSScriptRoot 'payload.zip'
if(Test-Path $zip){Remove-Item -LiteralPath $zip}
[IO.Compression.ZipFile]::CreateFromDirectory($payload,$zip)
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:winexe /optimize+ /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/resource:$zip,payload.zip" "/out:$root/F4E-Modern-Avionics.exe" (Join-Path $PSScriptRoot 'App/Manager.cs')
if($LASTEXITCODE){throw 'C# compilation failed'}
Get-FileHash -LiteralPath (Join-Path $root 'F4E-Modern-Avionics.exe')
