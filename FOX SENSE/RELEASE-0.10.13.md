FOX SENSE 0.10.13 fixes stretched HUD text and symbols on ultrawide and other non-16:9 displays.

- Adapts automatically to the actual DCS client-window dimensions, including 3440x1440 and 5120x1440; no resolution preset is needed.
- Keeps aircraft, missile and RWR symbols, labels, flight instruments and the SA map proportional while retaining projected target centers.
- Existing visuals respond to window resizing, and fractional SA-map size settings are preserved.
- Camera/FOV logic, export permissions, 60 Hz camera updates and 10 Hz world snapshots are unchanged.

Downloads: the guided Setup EXE, an EXE ZIP with English instructions, a Manual ZIP, and SHA256SUMS.txt. Close DCS and FOX SENSE before updating. Keep existing game-restoration backups and settings. Follow the project installation guide; preserve other mods' shared scripts. Portrait replacement remains optional.

Offline validation passed for actual WPF geometry at eight display-size scenarios, projected centers, text and symbol proportions, user sizing, resizing, existing HUD/control checks, and isolated installation/restoration with foreign-change protection. Public source, executable payloads and archives were scanned for private paths and identifiers. The attached installer is the exact locally tested build; its SHA256 is verified before and after upload.

Live appearance on the user's ultrawide display is still awaiting confirmation. This does not claim new in-game, VR, multiplayer IC or head-motion/FOV alignment validation. Standard single-camera desktop rendering is the intended target.

Free non-commercial use under the included license. Third-party materials retain their terms. GitHub source archives are not installation packages.
