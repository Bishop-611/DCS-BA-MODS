# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.3.0** for the Heatblur F-4E in **DCS 2.9.31.29434**.

- [Windows installer](F4E-Modern-Avionics-1.3.0.exe)
- [Pure manual ZIP](F4E-Modern-Avionics-1.3.0-Pure-Manual.zip)
- [Manual installation guide](MANUAL-INSTALLATION.txt)
- [SHA-256 checksums](SHA256-1.3.0.txt)

## Changes in 1.3.0

- The pilot and WSO brightness knobs follow the display setting through their full travel in radar and TV modes.
- Cockpit initialization now groups input bindings by device and reuses brightness settings across radar display elements. Both changes reduce setup work when entering the cockpit.
- A comparison with 1.2.46 found identical bindings for all 486 clickable cockpit controls and identical drawing data for all 102 radar page elements. Total mission loading time has not been benchmarked in game for this release.

## Windows installer

Exit DCS. Run the installer, select your DCS World folder and active Saved Games profile, and choose **Install**. Use **Check status** to verify the installation or **Restore** to uninstall. Keep the installer-managed backups. Undo manual modifications before switching from a manual installation.

Offline checks covered a fresh installation, upgrades from 1.2.36 and 1.2.46, and restoration. All 33 original game files matched after restoration.

## Manual installation

Extract the ZIP and follow the manual installation guide. Use File Explorer, a text editor, and the offline browser tool for the seven F-4E model patches. The manual ZIP was verified against the generated installation kit.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
