# FOX SENSE

[All projects](../README.md)

**Current stable version: 0.10.12**

FOX SENSE is a situational-awareness overlay for DCS World, designed to support older-generation jets facing modern threats. Available information depends on aircraft data and mission/server export permissions. Jester integration and the optional subtitle portrait apply to the F-4E.

[Download FOX SENSE 0.10.12](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/fox-sense-v0.10.12)

## Downloads

- **FOX-SENSE-0.10.12-Setup.exe**: the self-contained guided installer.
- **FOX-SENSE-0.10.12-EXE.zip**: the same installer, this English guide and the license.
- **FOX-SENSE-0.10.12-Manual.zip**: manual file-copy installation without the Setup EXE. Follow its English `README.txt`.
- **SHA256SUMS.txt**: SHA-256 checksums for all downloads.

Use one installation method and do not run multiple copies. GitHub's automatically generated source archives are not installation packages.

## Guided installation / update

1. Close DCS and FOX SENSE. Back up your installed FOX SENSE folder, profile `Scripts/Export.lua`, existing Jester mod scripts, `Scripts/Hooks/FoxViewFov.lua` and files under `Scripts/F4RwrLink` if present.
2. Run `FOX-SENSE-0.10.12-Setup.exe`, directly or after extracting the EXE ZIP.
3. Select your **DCS Saved Games profile**, normally `C:\Users\YOUR_WINDOWS_USER\Saved Games\DCS`. This is not the DCS game installation directory. Use an application subfolder under that profile's `Mods` folder.
4. Check your F-4E Jester mods location if using that integration, normally `Saved Games\DCS_F4E\jester\mods`.
5. Leave **Replace Jester portrait (optional)** unchecked to keep your current subtitle portrait. This does not replace the 3D crew model.
6. Select **Install / Update**, then restart DCS and launch FOX SENSE. Keep the installed `Backups` folder and `install-manifest.json`.

Existing EXE installations retain their settings. Update the runtime, Export bridge, GUI hook and activity helper together. The new bridge depends on the new HUD heartbeat; do not mix it with an older runtime.

## Manual installation / update

Follow `README.txt` inside the Manual ZIP. Merge folders without replacing an entire Saved Games profile. Append the supplied Export loader to your existing Export.lua and preserve other mods' loaders. Configure the Jester log path if using that integration.

Back up `Runtime/HudSettings.json` before copying, then restore it afterwards to retain your settings. Include `Scripts/F4RwrLink/FoxBridgeActivity.lua` and `Scripts/Hooks/FoxViewFov.lua`. Restart DCS after updating the scripts.

## Controls

Click the draggable FOX logo to open the menu. **JHMCS markers** controls target markers. **Flight data**, next to its size slider, controls the airspeed/altitude/HDG/AoA/Mach/G group. The bottom **HUD** switch controls all in-game displays while leaving menu access available. The close button hides the menu; use **Exit** to quit.

## Compatibility and limitations

Windows and DCS World are required. Data availability depends on the aircraft, mission and server export permissions. Cockpit-only visibility uses camera proximity rather than an exact camera-mode identifier. VR and custom multi-camera viewport alignment are not confirmed.

World observations now update at 10 Hz, which can add about 100 ms of discovery delay at normal simulation speed. The maintainer has accepted 0.10.12 as stable. Compatibility still depends on DCS updates, display configuration and server settings; this status does not imply universal IC or VR compatibility.

## Removal / restoration

Close FOX SENSE and DCS. Preserve newer changes from other mods. Remove only the FOX SENSE loader block in Export.lua; restore its bridge, activity helper, GUI hook and Jester scripts from the matching backups, or remove those exact files only if FOX SENSE originally added them. Restore the portrait backup if applicable. Then remove the application folder and shortcut. Do not replace a newer complete Export.lua with an old backup.

## License and support

[Non-commercial license](../LICENSE). Third-party materials retain their own terms; the font license is included in the package.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) with your DCS version, package version and reproduction steps.
