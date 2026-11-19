# F4E-Niko WSO

[All projects](../README.md)

**Current release v11**

Complete Niko rear-seat WSO replacement package for the Heatblur F-4E.

## Download

Download the installer executable and its SHA-256 checksum from the release assets. The GitHub download is named **F4E-Niko.WSO.exe**. The same installer is named **F4E-Niko WSO.exe** in the local release folder. [Download v11](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/f4e-niko-wso-v11)

## Changes in v11

- In the rear cockpit, Niko wraps her right hand around the control stick, rests her left hand on the throttle, and follows the rudder pedals with both feet. The cockpit shoes have a reshaped heel cup and a rounded opening around each ankle. The shoe changes apply only to the cockpit model.
- The rear first-person viewpoint is 6 mm higher and remains within the model's eye height.
- While the rear WSO is still attached to the ejection seat, the hands have been repositioned and the front skirt rests across the thighs. This change covers all four detail levels of the dedicated occupied rear seat.
- Warm skin and saturated pink hair carry through daylight and night lighting. Hair and face layers have shadow casting disabled to keep their shadows off the face. The face responds to ambient light and has no emission. The halo retains its glow.

The exported cockpit model was checked at 63 control settings, including both rudder extremes. Across those samples the hands and shoes tracked their controls and the stockings stayed inside the shoes. The v11 cockpit and ejection changes still need confirmation in a live F-4E mission.

## Rear ejection sequence

The dedicated rear seat and separate rear WSO use the reviewed Niko ejection poses. At seat separation, the occupant on the departing seat follows the original visibility switch. The rear skirt panels follow the hips during descent, landing and walking. All four rear WSO detail levels include the fitted garment.

## Included components

- Rear-seat character, external and cockpit models, and first-person body.
- Niko Jester portrait and 15,224 voice files.
- Nine Tape Player tracks with nine sound definitions.
- FOX PLATOON v0.13 livery with darker camouflage, stronger rivet/panel-seam detail, matte materials and repaired normal-map DDS headers.

FOX SENSE application and avionics are separate projects.

## Install and restore

1. Close DCS.
2. Run the installer and select the DCS installation and active Saved Games profile.
3. Choose **Install All**.
4. Keep the generated **NikoWSO_Backups** folder. Use **Restore All** to undo the installation.

Known v0.9–v0.12 livery revisions are accepted for upgrade. Existing resources are backed up. Repeated installation preserves the initial backups. Unsupported model versions or conflicting managed-file edits stop installation for review. The installer preserves other avionics modifications when merging its marked script sections.

See [detailed installation instructions](INSTALLATION.txt). If using FOX SENSE, leave its optional portrait replacement unchecked.

The warm texture palette was previously checked in DCS. Jester's AI look-around motion in the F2 external view also awaits in-game verification.

## Rear harness

The cockpit and close exterior views use Niko's harness in place of the original rear Koch straps that moved with the stock WSO skeleton.

## Character and animation

Rear-only ejection personnel and occupied ejection seats are replaced at all four native LODs, preserving native animation nodes and non-character seat/parachute geometry. Generic pilots and front-seat ejected crew are unchanged.

The character retains a 160 cm soles-to-crown scale, excluding ears and halo. LOD3 has 22,000 triangles, LOD4 has 7,499, and LOD5/6 hide the WSO. Native Jester observation and facial channels drive Niko with reduced motion for canopy clearance. The original rear WSO oxygen mask is removed.

The final installer passed a clean installation, an upgrade from v10 and restoration in isolated DCS folders. All 15,310 managed files were checked in both full-package tests. Repeat installation and restoration, conflict detection and preservation of existing user files also passed. Both intermediate face-shadow updates were accepted in separate upgrade tests.

## Rebuild the installer

From this project folder, run the following in 64-bit Windows PowerShell with .NET Framework 4.x installed. The script verifies the downloaded executable against the published checksum, reuses its payload and background, and compiles the installer with the source and icon from this repository.

```powershell
.\build\Build-Current.ps1 -ReleaseInstaller ".\F4E-Niko.WSO.exe" -OutputDirectory ".\Rebuilt"
```

The command writes `Rebuilt\F4E-Niko WSO.exe`. It runs independently of DCS.

## License

Third-party materials retain their respective terms. See the repository [license](../LICENSE).
