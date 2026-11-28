# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.3.4** for the Heatblur F-4E. The reference build is **DCS 2.9.32.30490**.

- [Windows installer](F4E-Modern-Avionics-1.3.4.exe)
- [Pure manual ZIP](F4E-Modern-Avionics-1.3.4-Pure-Manual.zip)
- [Manual installation guide](MANUAL-INSTALLATION.txt)
- [SHA-256 checksums](SHA256-1.3.4.txt)

## Changes in 1.3.4

- Calibrated the pitch ladder and flight-path marker to the native HUD optical scale. The zero-degree line represents the local horizontal, and the flight-path marker follows ground-relative velocity.
- Preserved the real flight-path direction in all HUD modes. A direction outside the original combiner's field of view remains clipped by the glass.
- Matched the CCIP and CCRP connecting cues to the calibrated flight-path marker while retaining the existing ballistic calculations.
- Reduced repeated DLZ marker allocation while preserving the displayed positions, line style and range scale.
- Updated AGM-88 release compatibility for the reference DCS build and retained the selected-target frame correction.
- Removed temporary validation traces. The existing HUD update rate and calculation caches are retained.

## Windows installer

Exit DCS. Run the installer, select your DCS World folder and active Saved Games profile, and choose **Install**. Existing installer-managed installations can use the same folders and choose **Install** to upgrade. Use **Check status** to verify the installation or **Restore** to uninstall. Keep the installer-managed backups. Undo manual modifications before switching from a manual installation.

Compatibility checks apply to the F-4E files used by the mod; the DCS version number alone does not block installation.

## Manual installation

Extract the ZIP and follow the manual installation guide. Use File Explorer, a text editor, and the offline browser tool for the seven F-4E model patches. Keep backups outside the game directory.

For the HARM page, select **A/G**, **AGM-88**, and the **RADAR** display source. Multiple stations may be preselected; the page follows the active store. **NWS** cycles emitters. TV retains the original video pages.

The small original HUD glass still limits the visible flight-path direction, including during landing. **ON SPEED** appears only with HUD **STBY** and the landing gear fully down.

The HUD changes were checked offline for projection and display geometry. Local AGM-88 tests confirmed releases with and without a selected emitter; multiplayer guidance has not been verified for this release. These changes do not claim to remove the first-load time of the official F-4E module.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
