# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.3.2** for the Heatblur F-4E. The reference build is **DCS 2.9.32.30490**.

- [Windows installer](F4E-Modern-Avionics-1.3.2.exe)
- [Pure manual ZIP](F4E-Modern-Avionics-1.3.2-Pure-Manual.zip)
- [Manual installation guide](MANUAL-INSTALLATION.txt)
- [SHA-256 checksums](SHA256-1.3.2.txt)

## Changes in 1.3.2

- The installer checks the F-4E files it needs. A change to the DCS version number alone no longer blocks installation.
- Players with an installer-managed 1.3.0 installation can upgrade directly after DCS updates the aircraft files. The installer backs up the updated originals for restoration.
- The cockpit display effect was rebuilt for the updated F-4E.

## Windows installer

Exit DCS. Run the installer, select your DCS World folder and active Saved Games profile, and choose **Install**. To upgrade from 1.3.0, use the same folders and choose **Install** directly. Use **Check status** to verify the installation or **Restore** to uninstall. Keep the installer-managed backups. Undo manual modifications before switching from a manual installation.

Offline checks covered a direct upgrade with a different DCS version number, a fresh installation without a version file, and restoration. All 32 tracked game files matched the updated originals after restoration. Custom bindings and the existing export hook were preserved.

## Manual installation

Extract the ZIP and follow the manual installation guide. Use File Explorer, a text editor, and the offline browser tool for the seven F-4E model patches. The manual ZIP was verified against the generated installation kit.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
