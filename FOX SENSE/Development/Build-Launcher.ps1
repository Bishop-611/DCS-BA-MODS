$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$dest=Join-Path $root 'Source\App';[void][IO.Directory]::CreateDirectory($dest)
$provider=New-Object Microsoft.CSharp.CSharpCodeProvider
$p=New-Object System.CodeDom.Compiler.CompilerParameters
$p.GenerateExecutable=$true;$p.GenerateInMemory=$false;$p.OutputAssembly=Join-Path $dest 'F4E FOX SENSE.exe'
$p.CompilerOptions='/target:winexe /optimize+ /win32icon:"'+(Join-Path $root 'F4E FOX SENSE.ico')+'" /win32manifest:"'+(Join-Path $root 'app.manifest')+'"'
foreach($r in @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Web.Extensions.dll')){[void]$p.ReferencedAssemblies.Add($r)}
$result=$provider.CompileAssemblyFromSource($p,[IO.File]::ReadAllText((Join-Path $root 'Launcher.cs')))
if($result.Errors.HasErrors){$result.Errors|ForEach-Object{Write-Output $_.ToString()};throw 'Launcher build failed'}
$provider.Dispose()
