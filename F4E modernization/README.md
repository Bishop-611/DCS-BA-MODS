# F4E modernization

Experimental radar and HUD modification for the DCS F-4E. **HUD and CCIP are one component.** The installer installs or restores radar and HUD together. No RWR modifications are included.

[Download the installer](F4E-Modern-Avionics.exe?raw=true) | [SHA-256](SHA256.txt)

## Version 1.0.3

In air-to-ground mode, CCIP falls back to the internal gun when no weapon station is selected, even if other ordnance is still carried. A selected supported weapon takes precedence. Empty cannon, unavailable selection data, and excluded weapon modes do not produce a false gun solution. This update has passed offline tests; live in-game validation is pending.

## Version 1.0.2

Saved input bindings are editable user data. Normal DCS binding edits no longer fail the installation/status hash check or block restoration. Restore preserves current physical bindings and only maps this package's command IDs back to their native IDs. Newly created device profiles are handled too; deleted binding files are not recreated. Original backups are retained, and files that need command-ID conversion are snapshotted outside the game directory before restoration.

This installer can restore existing 1.0.0 and 1.0.1 installations. Exit DCS, click **Restore**, then **Install** to update. The NWS fix from 1.0.1 is included. Conflicting native and routed entries in the same file still stop before changes rather than silently discarding either binding. Game files and Export.lua retain their modification protection.

## Version 1.0.1

Fixes NWS routing in device-specific joystick profiles (including HOTAS Warthog), which could override the routed command and split the same control into separate keyboard/joystick rows. All 11 supported input profiles now use the same routed NWS button command without changing native names or default physical bindings. Cage and other routed controls also pass through the final device-profile router.

For a physical joystick button, bind **Nose Gear Steering / Auto Acquisition Button**, without the **[SimPit]** prefix. The native **[SimPit] ... (Button)** entry is an axis-style hardware interface and is retained for compatibility.

To update from 1.0.0, fully exit DCS, click **Restore**, then **Install** with this installer. Earlier backups remain outside the game directory. Live in-game validation of this input fix is pending; isolated profile and installer checks passed.

## Installation and restoration

1. Download `F4E-Modern-Avionics.exe` and fully exit DCS.
2. Run the installer and select the DCS installation root and the correct Saved Games/DCS profile.
3. Click **Install**. Use **Check status** to verify installed files and backups.
4. To remove the modification, select the same paths and click **Restore**.

Supported baseline: **DCS 2.9.31.29434** with matching original F-4E files. The installer checks both the version and native file hashes. Updates or conflicting cockpit modifications stop installation. Restore before repairing or updating DCS. A changed baseline requires adaptation rather than bypassing checks.

Runtime files, original backups and installation records are stored under `%LOCALAPPDATA%\F4ModernAvionics`, outside the game directory. Keep this folder while using the modification. The EXE is self-contained; the Development directory is not needed to install.

Restore recovers pre-installation game and Export files. If Export.lua did not originally exist, it is removed. Later edits to those managed files stop restoration to avoid overwriting them. Saved input bindings are preserved as described above. Backups are retained. Existing unrelated Export hooks are preserved during installation.

## Features and controls

- avSimpleRadar search, STT and IFF; no TWS.
- Short Cage press cycles 5 / 10 / 25 / 50 NM. Holding Cage for about 0.6 seconds enters or exits ACM.
- ACM acquires within 10 NM. NWS breaks lock and reacquires the nearest target. In normal mode, NWS locks/unlocks and triggers IFF.
- Existing HCU, Cage and NWS binding options are reused. Matching saved bindings are migrated without adding binding options.
- Native air-to-air radar controls are intercepted; the radar power knob controls the new radar. Relevant air-to-ground controls are retained. AIM-7 interlock is forced OUT.
- HUD flight symbols, target box, IFF, range, gun lead, heat-seeker reference circle, AIM-7 DLZ and CCIP. HUD power and brightness controls are connected. Automatic uncage is disabled.
- CCIP uses the selected supported weapon profile. Gun fallback is used when no weapon is selected or other ordnance is exhausted, provided cannon ammunition remains. TV/IIR and anti-radiation missiles are excluded. Profiles cover modeled conventional/high-drag bombs, laser-guided bombs, rockets and selected cluster bombs.
- Native RWR display, receiver and audio are retained.

## Files changed

The installer modifies cockpit entry and clickable routing, existing input-profile entry points and the radar display shader. It appends the CCIP Export hook in Saved Games and migrates matching existing input bindings. Original files are backed up before target writes. Personal bindings, developer backups and historical logs are not included in this repository.

## Accuracy and validation

This is an experimental integration. DLZ uses a custom estimated envelope, not the closed native F-15/F-16 guidance algorithm; the display does not carry an EST label. CCIP uses modeled weapon parameters rather than a native encapsulated solver. Laser-guided bombs show an unguided reference impact point. Cluster bombs show the unopened parent-body reference point, not submunition dispersion. Zuni thrust, burn time and some drag parameters require live calibration. Unsupported weapons do not borrow a generic profile.

Passed offline checks: syntax for 37 Lua files; all 11 native keyboard/joystick profile routes; EXE payload extraction; isolated Windows PowerShell 5.1 installation, status check, repeated installation, binding migration, edited/new/deleted input profiles, restoration from an older receipt, non-binding later-edit protection, byte-for-byte restoration of unchanged files, initially absent Export.lua, and version rejection. **The integrated installer has not yet been reinstalled and validated in DCS.**

## Source and build

- `Development/Payload`: frozen installation source and pinned native baseline hashes.
- `Development/App/Manager.cs`: English Windows Forms interface.
- `Development/Build.ps1`: creates the embedded payload and compiles the EXE with the .NET Framework C# compiler. It retains the pinned native baseline hashes rather than recapturing a potentially modified game installation.
- `Development/Tests/Installer.ps1`: installer checks in an isolated directory. Use `-BaselineRoot` to select a directory containing verified original fixture files; the default is `D:/DCS/DCS World`. Fixture hashes are checked before testing.

Do not replace original baseline hashes with hashes from a modified installation. The compiled installer allows users to choose their own installation paths.
