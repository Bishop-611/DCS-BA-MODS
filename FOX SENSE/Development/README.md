# Building FOX SENSE 0.10.14

Editable source and required assets are included here. Use Windows PowerShell 5.1 with Windows .NET Framework and WPF:

```powershell
powershell.exe -NoProfile -STA -File .\Pack.ps1
```

Pack.ps1 compiles the launcher and runtime, runs the HUD and controls checks, generates the payload and compiles the installer. It does not install to DCS. Run Build-Manual.ps1 after Pack.ps1 for the manual edition; use a new StageRoot directory. Keep InstallHashes.txt and RuntimeInventory.json for upgrade ownership checks. Do not replace unknown shared-script changes with old backups.

Source/Overlay/AspectLayout.ps1 maintains proportional artwork around unchanged projection anchors. Test-AspectLayout.ps1 exercises actual WPF transforms across normal, wide and narrow windows, custom size controls and resizing. Source/Defaults contains distributed defaults, not a user's installed settings. Third-party font terms are retained in Source/Overlay/Fonts/OFL.txt.

The Release directory contains the tested installer. A fresh build may have a different checksum; generate and distribute its own checksums. Validation in this repository is offline and does not imply in-game acceptance.

Version 0.10.14 changes only the installer; the runtime and launcher remain 0.10.13. Build.ps1 recompiles the installer using an existing payload.zip. Use Pack.ps1 for a full build from source.
