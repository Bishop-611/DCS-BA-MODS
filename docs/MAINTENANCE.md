# Maintenance and DCS updates

[Back to projects](../README.md)

## Project boundaries

| Project | Main mechanism | Update-sensitive interfaces |
| --- | --- | --- |
| FOX SENSE | External overlay reads locally exported camera, flight and world snapshots | Export callbacks, GUI FOV, permissions, frame protocol and heartbeat |
| F4E Modern Avionics | Cockpit Lua and native ballistic integration extend original radar/display/input behavior | Native devices, input definitions, display elements, RWR controls and DLL/Lua interfaces |
| F4E-Niko WSO | Preserved native EDM structure with replacement rear-seat meshes and Lua animation | Model skeletons, LODs, draw arguments, visibility and shared cockpit scripts |

## Update workflow

1. Record the DCS and Heatblur versions and reproduce the reported change.
2. Compare fresh upstream files with the recorded baseline. Keep original models and installer backups.
3. Make the smallest necessary compatibility change while preserving accepted controls, visuals and behavior.
4. Merge only owned sections of shared scripts. Preserve other project modifications and user bindings.
5. Build a new version and run relevant regressions plus isolated install/check/restore tests.
6. Record offline checks separately from actual DCS results, including multiplayer and VR conditions when tested.
7. Publish the versioned package and checksum, verify downloads, then update the project guide and version table.

Never use an already modified EDM as the original merge source or bypass unknown-version checks merely to force installation. Do not commit game backups, proprietary upstream files, personal paths, logs, credentials, compiler caches or private resource archives.

## Public documentation

Use English throughout. Each project README follows Download, Install/Restore, Controls or Contents, Compatibility, and License/Support sections. Keep user instructions in project guides and development procedures here. Preserve attribution and existing license terms. Public source availability is limited to what is actually included in the repository.
