$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$source=[IO.File]::ReadAllText((Join-Path $root 'Installer.cs'))+"`n"+[IO.File]::ReadAllText((Join-Path $root 'Payload.cs')).Replace('using System.Collections.Generic;','')
$source+="`n"+[IO.File]::ReadAllText((Join-Path $root 'GameDetection.cs'))
$provider=New-Object Microsoft.CSharp.CSharpCodeProvider
$parameters=New-Object System.CodeDom.Compiler.CompilerParameters
$parameters.GenerateExecutable=$true
$parameters.GenerateInMemory=$false
$parameters.OutputAssembly=Join-Path $root 'F4E FOX SENSE Setup.exe'
$parameters.CompilerOptions='/target:winexe /optimize+ /win32icon:"'+(Join-Path $root 'F4E FOX SENSE.ico')+'" /win32manifest:"'+(Join-Path $root 'app.manifest')+'" /resource:"'+(Join-Path $root 'payload.zip')+'",Fox.Payload.zip'
foreach($reference in @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll','System.Web.Extensions.dll','System.IO.Compression.dll')){[void]$parameters.ReferencedAssemblies.Add($reference)}
$result=$provider.CompileAssemblyFromSource($parameters,$source)
if($result.Errors.HasErrors){$result.Errors|ForEach-Object {Write-Output $_.ToString()};throw 'Build failed'}
$provider.Dispose()
