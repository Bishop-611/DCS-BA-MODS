# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.2.36** for the Heatblur F-4E in **DCS 2.9.31.29434**.

- [Windows installer](F4E-Modern-Avionics-1.2.36.exe)
- [Pure manual ZIP](F4E-Modern-Avionics-1.2.36-Pure-Manual.zip)
- [Manual installation guide](MANUAL-INSTALLATION.txt)
- [SHA-256 checksums](SHA256-1.2.36.txt)

## Changes in 1.2.36

- The pilot and WSO display knobs now adjust brightness, contrast and RWR volume from the current panel setting on the first mouse movement.
- The TV display keeps the selected AGM-88 page through a brief gap in the station indication when another store remains.
- The RWR System Test button now plays a single headphone tone when the panel is powered and audio is enabled.

## Windows installer

Exit DCS. Run the installer, select your DCS World folder and active Saved Games profile, and choose **Install**. Use **Check status** to verify the installation or **Restore** to uninstall. Keep the installer-managed backups. Undo manual modifications before switching from a manual installation.

Fresh installation, upgrades from 1.2.31 and 1.2.35, and restoration passed offline checks. All 33 original files matched after restoration. Version 1.2.36 reached the cockpit in a local DCS session. Long mission loading times and intermittent early video between consecutive AGM-65Ds are still under investigation.

## Manual installation

Extract the ZIP and follow the manual installation guide. Use File Explorer, a text editor, and the offline browser tool for the seven F-4E model patches. The manual edition was checked against the clean supported baseline, including Lua syntax, input-profile edits, and model output hashes.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
