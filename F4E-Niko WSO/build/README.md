# Rebuild the Niko WSO v11 installer

From the project directory, use 64-bit Windows PowerShell and .NET Framework 4.x:

```powershell
.\build\Build-Current.ps1 -ReleaseInstaller ".\F4E-Niko.WSO.exe" -OutputDirectory ".\Rebuilt"
```

The public rebuild script verifies the downloaded installer against its published checksum, reuses its payload/background, and compiles the installer using this directory's source and icon. Output: `Rebuilt\F4E-Niko WSO.exe`. It does not install to DCS.
