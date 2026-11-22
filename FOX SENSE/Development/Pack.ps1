$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$utf8=[Text.UTF8Encoding]::new($false)
& (Join-Path $root 'Build-Launcher.ps1')
& (Join-Path $root 'Build-Runtime.ps1')
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$archive=Join-Path $root 'payload.zip'
if([IO.File]::Exists($archive)){[IO.File]::Delete($archive)}
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
try{
    foreach($file in Get-ChildItem (Join-Path $root 'Package') -Recurse -File | Sort-Object FullName){
        $key=$file.FullName.Substring((Join-Path $root 'Package').Length+1).Replace('\','/')
        $entry=$zip.CreateEntry($key,[IO.Compression.CompressionLevel]::Optimal)
        $input=[IO.File]::OpenRead($file.FullName);$output=$entry.Open()
        try{$input.CopyTo($output)}finally{$output.Dispose();$input.Dispose()}
    }
}finally{$zip.Dispose()}
$entries=@();$manifest=@()
foreach($file in Get-ChildItem (Join-Path $root 'Package') -Recurse -File | Sort-Object FullName){
    $key=$file.FullName.Substring((Join-Path $root 'Package').Length+1).Replace('\','/')
    $bytes=[IO.File]::ReadAllBytes($file.FullName)
    $entries+='{"'+$key+'","'+$key+'"},'
    $manifest+=@{path=$key;bytes=$bytes.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$payload="using System.Collections.Generic;`ninternal static partial class Fox {`nstatic readonly Dictionary<string,string> Payload = new Dictionary<string,string> {`n"+($entries -join "`n")+"`n};`n}"
$previous=[IO.File]::ReadAllText((Join-Path $root 'InstallHashes.txt'))
$hashes=[regex]::Match($previous,'static readonly string\[\] KnownHashes = new string\[\] \{[^}]+\};').Value
if(-not $hashes){throw 'Previous installer ownership hashes missing'}
$payload=$payload.Substring(0,$payload.Length-1)+$hashes+"`n}"
[IO.File]::WriteAllText((Join-Path $root 'Payload.cs'),$payload,$utf8)
[IO.File]::WriteAllText((Join-Path $root 'payload-manifest.json'),(ConvertTo-Json -InputObject $manifest -Depth 4),$utf8)
& (Join-Path $root 'Build.ps1')
Get-FileHash -LiteralPath (Join-Path $root 'F4E FOX SENSE Setup.exe') -Algorithm SHA256 | Format-List | Out-File (Join-Path $root 'SHA256.txt')
