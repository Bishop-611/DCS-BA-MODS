# FOX SENSE 0.10.8

FOX SENSE is an external situational-awareness overlay for DCS World, designed to support older-generation jets facing modern threats. Available information varies by aircraft, mission and server export permissions. Jester integration and the optional portrait apply to the F-4E.

[Download FOX SENSE 0.10.8](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/fox-sense-v0.10.8)

## Downloads

- **FOX-SENSE-0.10.8-EXE.zip**: extract and run `F4E FOX SENSE Setup.exe`. The single installer includes its runtime and scripts.
- **FOX-SENSE-0.10.8-Manual.zip**: file-copy installation without the Setup EXE. Follow the included `README.txt`, including the Jester log-path edit if using Jester.
- **SHA256SUMS.txt**: SHA-256 checksums for both downloads and the installer inside the EXE ZIP.

Choose one installation method. Do not run two copies simultaneously. GitHub's automatically generated source archives are not installation packages.

## Changes since 0.10.4

- Aircraft and missile markers share perspective projection based on the current camera pose, with live FOV data when available.
- Improved HUD window visibility recovery and cockpit-only hide/show behavior. The existing cockpit proximity detection is retained.
- Removed the menu's Ctrl+Alt+F10 hint. The menu shortcut itself is retained.
- Update rate remains capped at 30 Hz. Existing calibration controls and optional Jester subtitle portrait replacement are retained.

## EXE installation / update

1. Close FOX SENSE and DCS. Back up your FOX SENSE folder, profile `Scripts/Export.lua`, existing Jester mod scripts and `Scripts/Hooks/FoxViewFov.lua` if present.
2. Extract the EXE ZIP and run `F4E FOX SENSE Setup.exe`.
3. Select your DCS **Saved Games profile**, normally `C:\Users\YOUR_WINDOWS_USER\Saved Games\DCS`, and the application location under that profile's `Mods` folder. The profile is not the DCS game installation directory.
4. Check the F-4E Jester mods location if using that integration, normally `Saved Games\DCS_F4E\jester\mods`.
5. Leave **Replace Jester portrait (optional)** unchecked to retain the current subtitle portrait. This does not replace the 3D crew model.
6. Select **Install / Update**, then launch FOX SENSE. Restart DCS to load the GUI FOV hook when upgrading from 0.10.4. Keep the installed `Backups` folder and `install-manifest.json`.

Existing EXE installations retain settings. For a first alignment check, reset aircraft and missile calibration to 1.0, then adjust as needed. Missing FOV data falls back to manual calibration.

## Manual installation

Follow `README.txt` inside the Manual ZIP. Back up `Runtime/HudSettings.json` before copying and restore it afterwards to preserve settings. Merge folders without replacing an entire Saved Games profile. Append the supplied Export loader to your existing Export.lua; preserve other mods' loaders. The package includes `Scripts/Hooks/FoxViewFov.lua`, which loads on DCS startup.

## Controls and compatibility

Click the draggable FOX logo to open the menu. Use its HUD switch to show or hide the in-game displays; the menu stays available. The close button hides the menu; use **Exit** inside the menu to quit.

Cockpit-only visibility uses camera proximity, so it is an approximation rather than an exact camera-mode identifier. Standard single-view desktop rendering is the intended layout. VR and custom multi-camera viewport alignment are not confirmed. In-game HUD visibility was confirmed by the maintainer for this version. Multiplayer IC compatibility for this update has not been separately revalidated; information availability remains subject to server permissions.

## Antivirus alerts

Some antivirus products may flag the EXE. Such detections may be false positives but should be reviewed. Download from the official release and compare SHA-256 values with `SHA256SUMS.txt`; matching hashes establish file identity, not safety. A manual installation package is available. Do not disable antivirus protection.

## License and support

See `LICENSE` for the project's non-commercial terms. Third-party materials retain their own terms. The bundled font license is in `Runtime/Overlay/Fonts/OFL.txt`. Report issues at https://github.com/Bishop-611/DCS-BA-MODS/issues with installation method, DCS version and reproduction steps. Remove personal information before sharing logs.
