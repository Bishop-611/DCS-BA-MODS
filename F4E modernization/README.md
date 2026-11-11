# F4E Modern Avionics

[All projects](../README.md)

**Public download: 1.1.36. Maintainer-accepted local baseline: 1.1.40.**

The instructions below describe the published 1.1.36 package. Version 1.1.40 has not been uploaded here; do not rename the older installer to represent it.

## Download

The published radar, HUD and RWR modernization package for the Heatblur F-4E in DCS **2.9.31.29434**.

[Download the installer](F4E-Modern-Avionics-1.1.36.exe) and verify it against [SHA256.txt](SHA256.txt).

## Install and restore

1. Fully exit DCS.
2. Restore any previously managed installation with its installer before upgrading.
3. Open the new installer and select your DCS and Saved Games directories.
4. Select Install, then check status to verify managed files and backups.
5. Use Restore to return managed game files to their backed-up state.

Runtime files and backups are kept outside the game directory under the current user's Local AppData. Supported restoration preserves later input-binding edits. Conflicting edits to other managed files stop restoration for review. Unmanaged cockpit modifications or a different DCS baseline may prevent installation. Administrator privileges are needed only when the installation directory requires them.

## Existing controls

- A/A Cage short press cycles 5/10/25/50 NM. Hold Cage to enter or exit ACM.
- A/A NWS acquires or unlocks a target. In ACM it requests reacquisition of the nearest eligible return within 10 NM. STT and IFF remain available.
- Original HCU keys and axes move the radar cursor.
- A/G NWS hold switches CCIP/CCRP; short press designates or cancels a ground point. Original HCU controls adjust it.
- Hold the original Bomb Release through the valid release window for the original quantity/interval program.
- Existing HUD brightness, radar display controls and RWR AUDIO/DIM controls remain in use. No additional RWR bindings are required.
- Native TV and Pave Spike controls remain unchanged.

## Compatibility

Requires the supported Heatblur F-4E/DCS baseline. Conflicting cockpit modifications or later DCS updates may require adaptation. Multiplayer integrity-check compatibility is not claimed.

[Report an issue](https://github.com/Bishop-611/DCS-BA-MODS/issues) · [License](../LICENSE)
