F4E FOX SENSE 0.10.13 - Adaptive display proportions

Fixes stretched HUD text and symbols when the DCS window uses an aspect ratio other than 16:9, including 3440x1440 and 5120x1440. The overlay follows the actual DCS client window dynamically; no resolution preset is required. Symbol artwork and text scale uniformly while target centers retain their full-window projection. Existing size controls and settings remain available. Flight instruments, aircraft labels, missile symbols, RWR symbols and the SA map are covered. Fractional SA map size values are preserved.

Close FOX SENSE and DCS. Run FOX-SENSE-0.10.13-Setup.exe and select the existing active Saved Games profile and DCS folder. Install, then restart DCS and FOX SENSE. No automatic game installation was performed when building this package.

This changes HUD presentation only. It does not change DCS resolution, game aspect ratio, camera/FOV calibration, export permissions or update rates. Existing camera alignment limitations are unchanged.

Validation: actual WPF target and label transforms checked at 2560x1440, 3440x1440, 5120x1440, 1920x1080, 1920x1200, 1280x1024 and 2752x1152; existing map/RWR/flight instruments checked during resizing; custom symbol sizes and projected centers checked. Existing HUD and control checks passed. Isolated installer checks passed for reinstall, settings retention, original Export.lua restoration and rejection of foreign modifications. These are offline checks; live appearance on the user's ultrawide monitor remains to be confirmed. See the tagged release page for publication status and checksums.
