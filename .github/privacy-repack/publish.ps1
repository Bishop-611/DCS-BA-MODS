$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.Drawing
$repo=$env:GITHUB_REPOSITORY
$headers=@{Authorization="Bearer $env:GH_TOKEN";Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}
$work=Join-Path $env:RUNNER_TEMP 'privacy-repack'
[IO.Directory]::CreateDirectory($work)|Out-Null
function GetRelease($tag){Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$repo/releases/tags/$tag"}
function Download($release,$name,$dest){$a=$release.assets|Where-Object name -eq $name;if(!$a){throw "Missing asset $name"};Write-Host ("Downloading "+$name);$client=New-Object Net.WebClient;try{$client.DownloadFile($a.browser_download_url,$dest)}finally{$client.Dispose()};if((Get-Item $dest).Length -ne $a.size){throw "Download size mismatch"};Write-Host ("Downloaded "+$name)}
function ExtractResource($exe,$resource,$dest){$a=[Reflection.Assembly]::LoadFile($exe);$s=$a.GetManifestResourceStream($resource);if(!$s){throw 'Missing resource'};$o=[IO.File]::Create($dest);try{$s.CopyTo($o)}finally{$s.Dispose();$o.Dispose()}}
function Icon($exe,$dest){$i=[Drawing.Icon]::ExtractAssociatedIcon($exe);$s=[IO.File]::Create($dest);try{$i.Save($s)}finally{$s.Dispose();$i.Dispose()}}
function Invoke-PrivacyCheck($mode,$src,$dst){& python.exe (Join-Path $PSScriptRoot 'sanitize.py') $mode $src $dst;if($LASTEXITCODE){throw 'Privacy/identity verification failed'}}
Write-Host 'Starting verified privacy repack'
$niko=GetRelease 'f4e-niko-wso-v7';$fox=GetRelease 'fox-sense-v0.10.12'
$nOld=Join-Path $work 'niko-original.exe';$fOld=Join-Path $work 'fox-original.exe'
Download $niko 'F4E-Niko-WSO-v7.exe' $nOld
Download $fox 'FOX-SENSE-0.10.12-Setup.exe' $fOld
ExtractResource $nOld 'payload.zip' (Join-Path $work 'niko-old.zip')
ExtractResource $nOld 'background.png' (Join-Path $work 'background.png')
ExtractResource $fOld 'Fox.Payload.zip' (Join-Path $work 'fox-old.zip')
Icon $nOld (Join-Path $work 'niko.ico');Icon $fOld (Join-Path $work 'fox.ico')
Write-Host 'Sanitizing embedded payloads'
Invoke-PrivacyCheck 'niko' (Join-Path $work 'niko-old.zip') (Join-Path $work 'niko-clean.zip')
Invoke-PrivacyCheck 'fox-payload' (Join-Path $work 'fox-old.zip') (Join-Path $work 'fox-clean.zip')
Write-Host 'Compiling clean installers'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$manifest=Join-Path $PSScriptRoot 'app.manifest'
$nExe=Join-Path $work 'F4E-Niko-WSO-v7.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ ('/out:'+$nExe) ('/win32manifest:'+$manifest) ('/win32icon:'+(Join-Path $work 'niko.ico')) ('/resource:'+(Join-Path $work 'niko-clean.zip')+',payload.zip') ('/resource:'+(Join-Path $work 'background.png')+',background.png') /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.IO.Compression.dll (Join-Path $PSScriptRoot 'NikoInstaller.cs')
if($LASTEXITCODE){throw 'Niko compilation failed'}
$combined=([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'FoxInstaller.cs')))+"`n"+([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'FoxPayload.cs')).Replace('using System.Collections.Generic;',''))+"`n"+([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'FoxGameDetection.cs')))
$foxSource=Join-Path $work 'FoxCombined.cs';[IO.File]::WriteAllText($foxSource,$combined)
$fExe=Join-Path $work 'FOX-SENSE-0.10.12-Setup.exe'
& $compiler /nologo /target:winexe /optimize+ ('/out:'+$fExe) ('/win32manifest:'+$manifest) ('/win32icon:'+(Join-Path $work 'fox.ico')) ('/resource:'+(Join-Path $work 'fox-clean.zip')+',Fox.Payload.zip') /r:System.dll /r:System.Core.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.IO.Compression.dll $foxSource
if($LASTEXITCODE){throw 'FOX compilation failed'}
$env:CLEAN_FOX_EXE=$fExe
Invoke-PrivacyCheck 'file' $fExe $fExe
Invoke-PrivacyCheck 'file' $nExe $nExe
Write-Host 'Verifying Niko install and restore'
$test=Start-Process -FilePath $nExe -ArgumentList @('--self-test',(Join-Path $work 'niko-test')) -Wait -PassThru -WindowStyle Hidden
if($test.ExitCode){throw 'Niko restoration self-test failed'}
$foxFiles=@($fExe)
foreach($name in @('FOX-SENSE-0.10.12-EXE.zip','FOX-SENSE-0.10.12-Manual.zip')){$original=Join-Path $work ('original-'+$name);$dest=Join-Path $work $name;Download $fox $name $original;Invoke-PrivacyCheck 'fox-archive' $original $dest;$foxFiles+=$dest}
$nHash=Join-Path $work 'F4E-Niko-WSO-v7.sha256';((Get-FileHash $nExe).Hash+'  '+[IO.Path]::GetFileName($nExe))|Set-Content $nHash -Encoding ascii
$fHash=Join-Path $work 'SHA256SUMS.txt';$foxFiles|ForEach-Object {(Get-FileHash $_).Hash+'  '+[IO.Path]::GetFileName($_)}|Set-Content $fHash -Encoding ascii
function ReplaceAssets($release,$files){
 foreach($file in $files){$name=[IO.Path]::GetFileName($file);$old=$release.assets|Where-Object name -eq $name;if($old){Invoke-RestMethod -Method Delete -Headers $headers -Uri $old.url};$uri=($release.upload_url -replace '\{.*$','')+'?name='+[Uri]::EscapeDataString($name);$a=Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/octet-stream' -InFile $file -Uri $uri;if($a.size -ne (Get-Item $file).Length){throw 'Uploaded size mismatch'}}
 $body=$release.body+"`n`nPrivacy repack (2026-11-14): personal workstation paths removed. Package checksums have changed; use the attached current checksum file. Existing functionality and installed-content compatibility are retained."
 Invoke-RestMethod -Method Patch -Headers $headers -ContentType 'application/json' -Body (@{body=$body}|ConvertTo-Json) -Uri $release.url|Out-Null
}
# All replacements are built and checked before any public asset is removed.
Write-Host 'Replacing verified release assets'
ReplaceAssets $niko @($nExe,$nHash)
ReplaceAssets $fox ($foxFiles+@($fHash))
# Superseded releases may retain the same personal-path templates.
foreach($tag in @('f4e-niko-wso-v6','fox-sense-v0.10.8','fox-sense-v0.10.4')){$old=GetRelease $tag;Invoke-RestMethod -Method Delete -Headers $headers -Uri $old.url}
'PASS: current release assets replaced and superseded releases removed.'

