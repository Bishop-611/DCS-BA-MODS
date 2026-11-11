# F4E Modern Avionics

[All projects](../README.md)

**Current version: 1.1.41.**

## Download

The radar, HUD and RWR modernization package for the Heatblur F-4E in DCS **2.9.31.29434**.

[Download the installer](F4E-Modern-Avionics-1.1.41.exe) and verify it against [SHA256.txt](SHA256.txt).

## Install and restore

1. Fully exit DCS.
2. Open **F4E-Modern-Avionics-1.1.41.exe** and select your DCS and Saved Games directories.
3. Select **Install**. A recoverable older or partially restored installation is safely restored before the new package is installed. Do not delete its installation records or backups.
4. Select **Check status** to verify the installation.
5. Use **Restore** to remove managed avionics changes while preserving supported shared-script integrations.

Runtime files and backups are kept outside the game directory under the current user's Local AppData. Restoration preserves later input-binding edits, the delimited Niko WSO device block, and unrelated Export.lua plugins. Version 1.1.41 also fixes extraction of Windows-style empty ZIP directories. Unrecognized cockpit edits, modified avionics-owned export hooks, damaged backups, or unsupported game baselines still stop the operation for review. Unmanaged cockpit modifications or a different DCS baseline may prevent installation. Administrator privileges are needed only when the installation directory requires them.

Tested using the extracted EXE under Windows PowerShell 5.1: fresh install, safe upgrade, stale records without Niko, partial restoration, Niko installed before or after avionics, independent export plugins, conflict refusal, and exact restoration. The reported installation state was reproduced and recovered in an isolated copy; the live game was not modified. Flight-avionics content is unchanged from the accepted 1.1.40 baseline.

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
