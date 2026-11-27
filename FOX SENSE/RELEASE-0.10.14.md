# FOX SENSE 0.10.14

Fixes a false installation conflict when the Jester portrait exactly matches its saved original backup after an earlier FOX installation. The installer retains that original backup and still refuses unknown portrait changes.

The overlay runtime is unchanged from 0.10.13, including adaptive display proportions. The user previously confirmed the display fix at 3440x1440. Isolated installer/restore checks passed for this update; no new in-game validation is claimed.

Download Setup.exe or EXE.zip for guided installation, or Manual.zip for file-copy installation. SHA256SUMS.txt verifies all three downloads. Close DCS and FOX SENSE before updating. Preserve Backups, install-manifest.json and settings. Leave optional portrait replacement unchecked when using Niko WSO. Manual users must merge the supplied Export.lua block while preserving other mods and later edits.
