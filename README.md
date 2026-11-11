# DCS-BA-MODS

Three companion projects for DCS World and the Heatblur F-4E, maintained by Bishop-611.

## Choose a project

| Project | Purpose | Public download | Guide |
| --- | --- | --- | --- |
| FOX SENSE | External situational-awareness overlay and export bridge | [0.10.12](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/fox-sense-v0.10.12) | [Installation and controls](FOX%20SENSE/README.md) |
| F4E Modern Avionics | Cockpit radar, HUD, CCIP/CCRP and integrated RWR modernization | [1.1.36 installer](F4E%20modernization/F4E-Modern-Avionics-1.1.36.exe) | [Installation and controls](F4E%20modernization/README.md) |
| F4E-Niko WSO | Rear-seat character, portrait, voice, music and livery bundle | [v6](https://github.com/Bishop-611/DCS-BA-MODS/releases/tag/f4e-niko-wso-v6) | [Installation and contents](F4E-Niko%20WSO/README.md) |

The maintainer's accepted local Modern Avionics baseline is **1.1.40**. The publicly available installer in this repository is still **1.1.36**. The table links to files that are actually published.

Use the project-specific download above. This repository contains multiple products, so GitHub's global **Latest** release label does not identify the newest version of every project. Automatically generated source ZIPs are not installer packages.

## Installation overview

Close DCS before installing or restoring any package. Follow the selected project's guide and keep its backups.

| Project | Installation locations | Restore information |
| --- | --- | --- |
| FOX SENSE | Saved Games profile and application folder; optional F-4E portrait | Keep the application backups and installation manifest |
| F4E Modern Avionics | DCS F-4E files and selected Saved Games profile | Use the installer; keep its Local AppData state and backups |
| F4E-Niko WSO | DCS F-4E resources and livery in the selected Saved Games profile | Use Restore All; keep NikoWSO_Backups |

The projects have separate installers. When combining FOX SENSE with Niko WSO, leave optional FOX SENSE portrait replacement disabled to retain Niko's portrait. Do not overwrite entire shared Lua files with older copies.

## Documentation

- [Version and download policy](docs/RELEASES.md)
- [Maintenance and DCS update workflow](docs/MAINTENANCE.md)
- [Report a problem](docs/SUPPORT.md)
- [Contribute](CONTRIBUTING.md)

## License

Original materials are covered by the [DCS-BA-MODS Non-Commercial License](LICENSE), unless stated otherwise. Free non-commercial use, modification and redistribution are permitted under its conditions. Commercial use requires separate written permission. Third-party materials retain their own terms.

This is a source-available project with a non-commercial restriction, not an OSI-approved open-source project. Public repository contents do not include the complete private development workspace.

All repository documentation, comments, commit messages, issue templates and pull request text are maintained in English.
