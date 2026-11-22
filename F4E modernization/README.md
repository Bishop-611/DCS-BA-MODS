# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.2.31** for the Heatblur F-4E in **DCS 2.9.31.29434**.

- [Windows installer](F4E-Modern-Avionics-1.2.31.exe)
- [Pure manual ZIP](F4E-Modern-Avionics-1.2.31-Pure-Manual.zip)
- [Manual installation guide](MANUAL-INSTALLATION.txt)
- [SHA-256 checksums](SHA256-1.2.31.txt)

## Changes in 1.2.31

- AIM-120B supports no-lock (Maddog) release and retains the existing STT path.
- AGM-88 selection retains the last selected position when the emitter disappears. Press NWS to select another available target.
- Includes the increased RWR audio gain from 1.2.30.

## Windows installer

Exit DCS. Run the installer, select your DCS World folder and active Saved Games profile, and choose **Install**. Use **Check status** to verify the installation or **Restore** to uninstall. Keep the installer-managed backups. Undo manual modifications before switching from a manual installation.

Offline regression, package integrity, and first-time installation checks passed. Install, Check status, and Restore were tested against a clean supported DCS file set and an empty Saved Games profile. Live DCS launch behavior and multiplayer compatibility are pending verification.

## Manual installation

Extract the ZIP and follow the manual installation guide. Use File Explorer, a text editor, and the offline browser tool for the seven F-4E model patches. The manual edition was checked against the clean supported baseline, including Lua syntax, input-profile edits, and model output hashes.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
