# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.1.43** for Heatblur F-4E / **DCS 2.9.31.29434**.

## Downloads

- [EXE installer](F4E-Modern-Avionics-1.1.43.exe): graphical Install, Check status and Restore.
- [Pure manual ZIP](F4E-Modern-Avionics-1.1.43-Pure-Manual.zip): File Explorer and text-editor installation. No PowerShell, command prompt or EXE required.
- [Pure manual installation guide](MANUAL-INSTALLATION.txt)
- [SHA-256 checksums](SHA256.txt)

Both editions provide the same avionics functions. The manual edition resolves runtime locations from your active Saved Games profile. It requires copying files and making the documented Lua merges; it is not a one-folder drag-and-drop mod.

## EXE installation

Close DCS, run the installer, select the DCS World root and active Saved Games profile, then click **Install**. Use **Check status** to verify files or **Restore** to uninstall. Recognized older installations are safely restored before upgrading.

Keep `%LOCALAPPDATA%/F4ModernAvionics/Installations` while installed: it contains runtime files and original backups. Unsupported baselines, damaged backups and unknown edits stop installation. Do not bypass these checks. Supported Niko blocks, unrelated Export.lua additions and later input-binding edits are preserved.

## Pure manual installation

Extract the ZIP and follow its README using File Explorer and a text editor. Back up the listed files first. Copy the DCS and SavedGames contents to the corresponding folders, then apply the supplied exact replacement and append snippets. Preserve existing Niko and other mod content. No personal machine path is embedded.

The manual edition is unmanaged: it does not create EXE installation receipts. Restore an EXE-managed installation before applying the manual edition. Undo the manual changes before switching back to the EXE. The guide includes binding migration and uninstall instructions.

## Changes and controls

1.1.43 uses panel parameter gauges for the original **5/10/25/50 NM** radar range lamps, replacing the unsuccessful direct-argument approach in 1.1.42.

- Short Cage press cycles ranges; hold for 10 NM ACM.
- A/A NWS acquires/unlocks; HCU moves the radar cursor. STT and IFF remain available.
- A/G NWS hold switches CCIP/CCRP; short press designates/cancels a point.
- Hold Bomb Release through the valid release window.
- Existing HUD brightness, RWR AUDIO/DIM, TV and Pave Spike controls remain available.

## Validation

EXE extraction, isolated installation/reinstallation/restoration, editable bindings, Niko/shared-panel preservation and conflict refusal passed under Windows PowerShell 5.1. The pure manual package has separate Lua syntax and path-transformation checks; a separate in-game manual-install test is not claimed. Future DCS updates may require adaptation. Multiplayer integrity-check compatibility is not claimed.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
