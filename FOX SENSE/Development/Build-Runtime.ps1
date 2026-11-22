$ErrorActionPreference='Stop'
$root=$PSScriptRoot;$source=Join-Path $root 'Source\Overlay';$stage=Join-Path $root 'Package'
[void][IO.Directory]::CreateDirectory($stage)
foreach($folder in @('App','Bridge','Branding','Defaults','Portrait')){Copy-Item -LiteralPath (Join-Path $root ('Source\'+$folder)) -Destination $stage -Recurse -Force}
$out=Join-Path $stage 'Overlay';[void][IO.Directory]::CreateDirectory($out)
foreach($item in Get-ChildItem $source){if($item.PSIsContainer){Copy-Item -LiteralPath $item.FullName -Destination $out -Recurse -Force}elseif($item.Extension -ne '.cs'){Copy-Item -LiteralPath $item.FullName -Destination $out -Force}}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$support=[regex]::Replace([IO.File]::ReadAllText((Join-Path $source 'ControlsFocus.cs')),'(?m)^using [^;]+;','')
$code=[IO.File]::ReadAllText((Join-Path $root 'Runtime.cs'))+"`r`n"+$support
$provider=New-Object Microsoft.CSharp.CSharpCodeProvider
$p=New-Object CodeDom.Compiler.CompilerParameters
$p.GenerateExecutable=$false;$p.GenerateInMemory=$false;$p.OutputAssembly=Join-Path $out 'Fox.Runtime.dll';$p.CompilerOptions='/optimize+'
foreach($ref in @('System.dll','System.Core.dll',[Windows.Interop.HwndSource].Assembly.Location,[Windows.Threading.Dispatcher].Assembly.Location)){[void]$p.ReferencedAssemblies.Add($ref)}
$result=$provider.CompileAssemblyFromSource($p,$code)
if($result.Errors.HasErrors){$result.Errors|ForEach-Object {Write-Output $_.ToString()};throw 'Runtime build failed'}
$provider.Dispose()
foreach($file in Get-ChildItem $out -Filter '*.ps1'){
 $text=[IO.File]::ReadAllText($file.FullName);$tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw ('Runtime parse error: '+$file.Name)}
 foreach($token in @($tokens|Where-Object Kind -eq Comment|Sort-Object {$_.Extent.StartOffset} -Descending)){$text=$text.Remove($token.Extent.StartOffset,$token.Extent.EndOffset-$token.Extent.StartOffset)}
 [IO.File]::WriteAllText($file.FullName,$text,[Text.UTF8Encoding]::new($false))
}
$shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $shell -NoProfile -STA -ExecutionPolicy RemoteSigned -File (Join-Path $out 'Overlay.ps1') -SelfTest | Out-File (Join-Path $root 'runtime-check.txt')
if($LASTEXITCODE -ne 0){throw 'Runtime checks failed'}
& $shell -NoProfile -STA -ExecutionPolicy RemoteSigned -File (Join-Path $out 'Overlay.ps1') -Demo -RuntimeControlsTest | Out-File (Join-Path $root 'controls-check.txt')
if($LASTEXITCODE -ne 0){throw 'Control checks failed'}
# Keep development fixtures outside the customer installation.
foreach($file in Get-ChildItem $out -Filter 'Test-*.ps1'){Remove-Item -LiteralPath $file.FullName}
foreach($name in @('HudSettings.json','Settings-test.json')){ $file=Join-Path $stage $name;if([IO.File]::Exists($file)){[IO.File]::Delete($file)} }
$main=Join-Path $out 'Overlay.ps1';$text=[IO.File]::ReadAllText($main)
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
$block=$ast.Find({param($a) $a -is [Management.Automation.Language.IfStatementAst] -and $a.Clauses[0].Item1.Extent.Text -eq '$SelfTest'},$true)
if($null -eq $block){throw 'Runtime entry check missing'}
$smoke='if($SelfTest){$null=Load-Xaml ''Controls.xaml'';$v=[FoxGeometry]::A(0,1,0,0,12,1);if($v.Length -ne 3){throw ''Runtime initialization failed''};Write-Output ''PASS: runtime initialization'';exit}'
$text=$text.Remove($block.Extent.StartOffset,$block.Extent.EndOffset-$block.Extent.StartOffset).Insert($block.Extent.StartOffset,$smoke)
[IO.File]::WriteAllText($main,$text,[Text.UTF8Encoding]::new($false))
$inventory=@{}
$seed=[IO.File]::ReadAllText((Join-Path $root 'RuntimeInventory.json'))|ConvertFrom-Json
foreach($property in $seed.PSObject.Properties){$inventory[$property.Name]=@($property.Value)}
foreach($version in Get-ChildItem (Split-Path $root) -Directory -Filter 'F4E-FOX-SENSE-*'){
 $folder=Join-Path $version.FullName 'Source\Overlay'
 if(-not [IO.Directory]::Exists($folder)){continue}
 foreach($file in Get-ChildItem $folder -File | Where-Object {$_.Name -like 'Test-*.ps1' -or $_.Name -eq 'ControlsFocus.cs'}){
  if(-not $inventory.ContainsKey($file.Name)){$inventory[$file.Name]=@()}
  $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  if($inventory[$file.Name] -notcontains $hash){$inventory[$file.Name]+=$hash}
 }
}
[IO.File]::WriteAllText((Join-Path $stage 'App\RuntimeInventory.json'),($inventory|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
