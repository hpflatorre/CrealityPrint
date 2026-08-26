# Creality CR-200B profiles

Creality dropped the CR-200B after Creality Print **4.3.8** (Cura-based) and has
said there is no plan to port it to the OrcaSlicer-based 5.x+ line
(see [#424](https://github.com/CrealityOfficial/CrealityPrint/issues/424)).

This directory holds the tooling that re-authors the 4.3.8 definitions in the
7.x profile schema. The generated files are committed under
`resources/profiles/Creality/` so builds of this fork ship the printer; the
tooling is kept so the presets can be regenerated (or injected into an
official AppImage) when either side changes.

| file | purpose |
|---|---|
| `make_cr200b.py <resources/profiles>` | (re)generates the machine model, machine, 3 process and 3 filament presets and registers them in `Creality.json`. Idempotent. |
| `reapply.sh <stock.AppImage> [out.AppImage]` | extracts an official AppImage, runs the generator, repacks it (needs `squashfs-tools`; reuses the source AppImage's own runtime, no appimagetool required). |

## What the profile encodes

Values are taken verbatim from 4.3.8's `Machines/CR-200B.default`,
`Extruders/CR-200B/extruder_0_0.4.default` and `Materials/CR-200B/*.default`:

- 200 × 200 × 200 mm, origin at corner, **Bowden** extruder, 0.4 mm nozzle, 1.75 mm filament
- retraction 4 mm @ 40 mm/s (retract and prime)
- max acceleration X/Y/Z/E = 500/500/**100**/5000 — the Z=100 is what
  distinguishes it from the Ender-3 V2 donor
- enclosed but unheated chamber, chamber fan and LED present
- filaments: PLA 210/50 °C, ABS 260/100 °C, PETG 250/70 °C

The 7.x schema donor is **Creality Ender-3 V2 0.4 nozzle** — same class of
machine (i3 bedslinger, Bowden, Marlin) with identical `machine_max_*` limits
and purge-line geometry.

## Caveats

- **CR-200B Pro is a different machine** (direct drive, 220 mm Z) and is not covered.
- The ABS preset carries 4.3.8's 70 % part-cooling fan, which is high for ABS
  in an enclosure (Creality's generic ABS uses 10–20 %). Lower it if parts warp.
- The cover image is a placeholder; Creality never shipped one for this model.
