# Rebuild the Windows installer with the current source and the published v12.2 assets.
param(
    [Parameter(Mandatory)][string]$ReleaseInstaller,
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot) 'Release')
)
$ErrorActionPreference = 'Stop'
$source = (Get-Item -LiteralPath $ReleaseInstaller).FullName
$checksums = Join-Path (Split-Path $PSScriptRoot) 'F4E-Niko-WSO-v12.2.sha256'
$record = (Get-Content -LiteralPath $checksums -Raw).TrimEnd()
if ($record -notmatch '^(?<hash>[A-Fa-f0-9]{64})  F4E-Niko\.WSO\.exe$') {
    throw 'The v12.2 release checksum record is missing or invalid.'
}
$expected = $Matches['hash']
$output = [IO.Path]::GetFullPath($OutputDirectory)
$installer = Join-Path $output 'F4E-Niko WSO.exe'
if ([IO.File]::Exists($installer)) { throw "Choose a new output directory. $installer already exists." }

$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not [IO.File]::Exists($compiler)) { throw 'Use 64-bit Windows with .NET Framework 4.x installed.' }
[IO.Directory]::CreateDirectory($output) | Out-Null
$stage = Join-Path $output ('niko-build-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage) | Out-Null
$payload = Join-Path $stage 'payload.zip'
$background = Join-Path $stage 'background.png'
$manifest = Join-Path $stage 'app.manifest'
$compiled = Join-Path $stage 'F4E-Niko WSO.exe'
try {
    # Hold a read-only handle through verification and extraction.
    $file = [IO.File]::Open($source, 'Open', 'Read', 'Read')
    try {
        $actual = (Get-FileHash -InputStream $file -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw 'The supplied installer does not match the published v12.2 SHA-256.' }
        $assembly = [Reflection.Assembly]::LoadFile($source)
        foreach ($asset in @('payload.zip','background.png')) {
            $embedded = $assembly.GetManifestResourceStream($asset)
            if (-not $embedded) { throw "The release installer is missing $asset." }
            try {
                $copy = [IO.File]::Create((Join-Path $stage $asset))
                try { $embedded.CopyTo($copy) } finally { $copy.Dispose() }
            } finally { $embedded.Dispose() }
        }
    } finally { $file.Dispose() }
    [IO.File]::WriteAllText($manifest, @'
<?xml version="1.0" encoding="utf-8"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges>
    <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
  </requestedPrivileges></security></trustInfo>
</assembly>
'@)
    $options = @(
        '/nologo', '/target:winexe', '/platform:x64', '/optimize+',
        "/out:$compiled", "/win32manifest:$manifest",
        ('/win32icon:' + (Join-Path $PSScriptRoot 'niko-icon.ico')),
        "/resource:$payload,payload.zip", "/resource:$background,background.png",
        '/r:System.Windows.Forms.dll', '/r:System.Drawing.dll',
        '/r:System.Web.Extensions.dll', '/r:System.IO.Compression.dll',
        (Join-Path $PSScriptRoot 'NikoInstaller.cs')
        (Join-Path $PSScriptRoot 'TapeCache.cs')
    )
    & $compiler @options
    if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed with exit code $LASTEXITCODE." }
    [IO.File]::Move($compiled, $installer)
    Write-Output $installer
} finally {
    foreach ($path in @($payload,$background,$manifest,$compiled)) { [IO.File]::Delete($path) }
    [IO.Directory]::Delete($stage)
}
