# F4E Modern Avionics

[All projects](../README.md) · [Support](../docs/SUPPORT.md)

**Public download: 1.1.36. Maintainer-accepted local baseline: 1.1.40.**

The instructions below describe the published 1.1.36 package. Version 1.1.40 has not been uploaded here; do not rename the older installer to represent it.

## Download

The published radar, HUD and RWR modernization package for the Heatblur F-4E in DCS **2.9.31.29434**.

[Download the installer](F4E-Modern-Avionics-1.1.36.exe) and verify it against [SHA256.txt](SHA256.txt).

This directory distributes the installer and user-facing documentation. Separate RWR source and implementation documentation are not published. The installer contains the required runtime files and is not an encrypted or source-protected distribution. Outdated development files were removed from the current directory; prior revisions remain in Git history.

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

## Changes in 1.1.36

Reduced redundant HUD calculations, repeated input/export work and routine diagnostic overhead. Accepted controls and display behavior are preserved. Requested rates remain 120 Hz for the radar cursor, 30 Hz for target projection and 60 Hz for the HUD; actual rates depend on DCS scheduling and frame rate.

Ballistic accuracy and release conditions are unchanged. No new terrain approximation is introduced. The package requires no Python runtime or external background worker.

## Validation and limitations

The actual installer passed isolated installation, status-check, repeated-installation, binding-migration, conflict-protection and restoration tests. Functional regressions cover radar controls, cursor rendering, HUD modes, CCIP/CCRP selection and release, and RWR user controls.

These checks are not an in-game flight test and do not establish a specific FPS improvement. Native solves and real terrain queries can still cause frame-time spikes. Multiplayer export restrictions and version compatibility apply; integrity-check compatibility is not claimed.

No personal logs, backups, mission recordings or input-binding profiles are included. Third-party notices remain in the package; inclusion does not grant additional rights to third-party material.
