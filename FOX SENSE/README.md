# FOX SENSE 0.10.13

Situational-awareness overlay for DCS World. Jester integration and the optional portrait apply to the F-4E.

[Download 0.10.13](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/fox-sense-v0.10.13) · [All projects](../README.md)

HUD text and symbols automatically retain their proportions as the DCS window changes size. The user confirmed the fix on a **3440x1440** ultrawide display.

## Downloads and installation

- **Setup.exe**: guided installer; **EXE.zip** includes the same installer and instructions.
- **Manual.zip**: follow its README for file-copy installation.
- **SHA256SUMS.txt**: checksums for the downloads.

Close DCS and FOX SENSE. Run the installer, select your active **DCS Saved Games profile** (not the game installation folder), and choose **Install / Update**. Keep the application under that profile's Mods folder. Check the Jester mods location if using the F-4E integration. Leave optional portrait replacement unchecked when using Niko WSO. Restart DCS and FOX SENSE after updating.

Keep the installed Backups folder, install-manifest.json and settings. For manual updates, preserve Runtime/HudSettings.json and merge the supplied Export.lua block without replacing other mods' loaders. Use one installation method; do not mix versions or run duplicate copies.

## Controls and removal

Click the FOX logo for settings. **JHMCS markers**, **Flight data**, and **HUD** control their respective displays. Closing the menu hides it; **Exit** quits.

To remove, close both programs and remove only the FOX loader block and its managed files. Restore matching backups where applicable, preserving later edits by other mods. Do not overwrite an entire newer Export.lua with an old backup. Restore the optional portrait backup if used.

Data depends on aircraft and mission/server export permissions. VR, custom multi-camera layouts and multiplayer IC are not confirmed. This display fix does not address unrelated head-motion/FOV alignment issues.

[Build instructions](Development/README.md) · [Support](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
