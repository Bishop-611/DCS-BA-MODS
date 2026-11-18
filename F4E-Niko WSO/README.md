# F4E-Niko WSO

[All projects](../README.md)

**Current version: v10**

Complete Niko rear-seat WSO replacement package for the Heatblur F-4E.

## Download

[Download v10](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/f4e-niko-wso-v10). Select **F4E-Niko-WSO-v10.exe** and its SHA-256 file from the release assets.

## Rear ejection update

The occupied rear seat and separate rear WSO now use the reviewed Niko ejection poses. The front skirt rests across the thighs during ejection. The rear panels follow the hips during descent, landing and walking. All four ejection detail levels include the corrected garment.

## Included components

- Rear-seat character, external and cockpit models, and first-person body.
- Niko Jester portrait and 15,224 voice files.
- Nine Tape Player tracks with nine sound definitions.
- FOX PLATOON v0.13 livery: darker camouflage, stronger rivet/panel-seam detail, matte materials and repaired normal-map DDS headers.

FOX SENSE application and avionics are separate projects.

## Install and restore

1. Close DCS.
2. Run the installer and select the DCS installation and active Saved Games profile.
3. Choose **Install All**.
4. Keep the generated **NikoWSO_Backups** folder. Use **Restore All** to undo the installation.

Known v0.9–v0.12 livery revisions are accepted for upgrade. Existing resources are backed up. Repeated installation preserves the initial backups. Unsupported model versions or conflicting managed-file edits stop installation for review. The installer preserves other avionics modifications when merging its marked script sections.

See [detailed installation instructions](INSTALLATION.txt). If using FOX SENSE, leave its optional portrait replacement unchecked.

The warm texture and hair-shadow appearance was accepted after a temporary game installation. This release also includes rear-only ejection models; their landing and movement appearance still requires in-game verification. External Jester animation troubleshooting was deferred.

## Rear harness fix

Removes duplicate original rear Koch straps that continued following the original WSO skeleton. Niko's own harness and all front-seat straps are retained. The cockpit and near-distance external models are updated; other v8 resources and original restoration baselines are unchanged.

## Character and animation

The v9 materials preserve warm skin and saturated pink hair without global darkening. Hair does not cast shadows; the face still responds to day/night lighting and has no self-illumination. Rear-only ejection personnel and occupied ejection seats are replaced at all four native LODs, preserving native animation nodes and non-character seat/parachute geometry. Generic pilots and front-seat ejected crew are unchanged.

The character retains a 160 cm soles-to-crown scale, excluding ears and halo. LOD3 has 22,000 triangles, LOD4 has 7,499, and LOD5/6 hide the WSO. Native Jester observation and facial channels drive Niko with reduced motion for canopy clearance. Hands and feet follow the original controls. The original rear WSO oxygen mask is removed.

## License

Third-party materials retain their respective terms. See the repository [license](../LICENSE).

## Previous validation

The complete isolated installation/restoration test passed, including repeat operations, conflict protection, pre-existing resource restoration, new-file removal and unrelated avionics script preservation. All payload hashes and prior v7 manifest compatibility passed.

## v9 validation

Package hashes passed. The actual installer passed v8 upgrade, repeated install/restore, conflict protection, exact model/texture restoration and preservation of unrelated avionics script content. Unchanged bulk resources retain the complete v8 installation/restoration coverage.
