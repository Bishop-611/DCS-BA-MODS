# FOX SENSE 0.10.4

FOX SENSE is an external information overlay for the DCS F-4E. It provides configurable flight information and situational-awareness displays using available export and Jester data. Information availability depends on the mission and server export permissions.

[Download FOX SENSE 0.10.4](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/fox-sense-v0.10.4)

## Choose a download

| Download | Installation |
| --- | --- |
| `FOX-SENSE-0.10.4-EXE.zip` | Recommended: extract it and run `F4E FOX SENSE Setup.exe`. Includes this guide and the license. |
| `FOX-SENSE-0.10.4-Manual.zip` | For users who prefer file copying: extract it and follow its `README.txt`. No Setup EXE is required. |

Choose one method. Both contain the same version of the runtime. Do not run two copies of FOX SENSE simultaneously. GitHub's automatically generated source archives are not installation packages.

## EXE installation

1. Close DCS and any running FOX SENSE instance. Before upgrading, back up your FOX SENSE folder, the DCS profile's `Scripts/Export.lua`, and existing Jester mod files.
2. Extract the EXE ZIP to a local folder and run `F4E FOX SENSE Setup.exe`.
3. Check **DCS Saved Games profile**. Select the profile you actually use, normally `C:\Users\YOUR_WINDOWS_USER\Saved Games\DCS`. This is the Saved Games profile, not the DCS game installation folder.
4. Check **Install location (Saved Games Mods folder)**. The normal location is `<PROFILE>\Mods\F4E FOX SENSE`. If using a `DCS.*` profile, point both profile and application locations to that profile.
5. Check **F-4E Jester mods folder**, normally `C:\Users\YOUR_WINDOWS_USER\Saved Games\DCS_F4E\jester\mods`.
6. Leave **Replace Jester portrait (optional)** unchecked to keep your current portrait. Select it only if you want the supplied subtitle portrait. This does not replace the rear-seat 3D model.
7. Click **Install / Update** and wait for successful completion. Use the completion screen or the Start menu entry to launch FOX SENSE. After a Jester bridge update, re-enter the F-4E cockpit.

The installer integrates the Export and Jester scripts and backs up existing files that it changes. Keep the entire installed folder, including `Backups` and `install-manifest.json`. Do not move only the launcher EXE.

## Manual installation

Follow the `README.txt` inside the Manual ZIP in order. It includes exact copy destinations, the required Jester log-path edit, the Export.lua loader, optional portrait installation, and restoration steps. Preserve other mods' Export.lua content. On upgrade, back up your existing `Runtime/HudSettings.json` before copying and restore it afterward to keep your settings.

## Controls and version changes

- Use the menu's HUD switch to show or hide the overlay. Version 0.10.4 removes the separate custom HUD visibility shortcut.
- The logo is retained; the update rate is capped at 30 Hz.
- Portrait replacement is optional and disabled by default in the installer.

## Removal and restoration

Close DCS and FOX SENSE. Back up the current files before changing them.

1. Remove only the FOX SENSE loader between `F4RWRLINK_BEGIN` and `F4RWRLINK_END` in your profile's `Scripts/Export.lua`. Preserve all other mods' code.
2. Restore `F4RwrProbe.lua` and `init/StartF4RwrProbe.lua` in the Jester mods folder from your pre-installation backups; remove those exact files only if FOX SENSE originally added them.
3. Restore your previous `Scripts/F4RwrLink/ExportBridge.lua`, or remove that exact file if newly added. Do not remove a shared folder containing other files.
4. If you installed the optional portrait, restore the original `jester_portrait.png` from your backup.
5. After restoring the external files, remove the FOX SENSE application folder and its Start menu shortcut if present.

The EXE installation records changed-file targets and backup paths in `install-manifest.json`. Use those records to locate the matching backups. Preserve newer changes made by other mods; do not blindly restore an old complete Export.lua.

## Compatibility and support

Windows and the DCS F-4E are required. DCS in-game operation and multiplayer Integrity Check (IC) compatibility have been tested and confirmed by the project maintainer. Results apply to the tested environment; DCS updates or different server settings may affect compatibility. An external desktop overlay should not be assumed to support VR.

If installation stops on a conflicting file, back up and review it before proceeding. For display problems, check the selected Saved Games profile, Export.lua loader, Jester log path, and server export permissions.

Report issues at https://github.com/Bishop-611/DCS-BA-MODS/issues with your DCS version, installation method, reproduction steps, and screenshots. Remove personal details before sharing logs.

## Antivirus alerts

Some antivirus products may flag the EXE installer. Such alerts may be false positives, but an alert should not be assumed harmless. Download only from the official GitHub release and compare the file's SHA-256 with SHA256SUMS.txt. Matching hashes confirm the download matches the published file; they do not prove it is safe. If an alert appears, review the detection or report it to the maintainer and antivirus vendor. Do not disable antivirus protection. The Manual ZIP is available if you prefer not to run the Setup EXE; its scripts may also be scanned.

## License

Original project materials use the included `LICENSE`: free non-commercial use, modification, and redistribution are permitted under its conditions. Commercial use requires separate written permission from the applicable copyright holders. Third-party materials retain their own terms; the font license is included at `Runtime/Overlay/Fonts/OFL.txt` in the installed application or manual package.