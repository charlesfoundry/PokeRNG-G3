# PokeRNG G3

PokeRNG G3 is a Flutter/Dart tool for Generation 3 RNG workflows, focused on
Pokemon Emerald, FireRed, and LeafGreen.

The app is designed for practical use on phones and desktop: search a target,
save it, time the attempt on retail hardware, then calibrate from the Pokemon
you actually hit.

## Features

- Wild encounter search for Emerald, FireRed, and LeafGreen
- Static, gift, legendary, event, and roamer search
- Emerald retail timer with 5-second preparation countdown and audio cue
- Calibration from observed wild/static results
- Saved targets per game version
- Gen 3 stat calculator and IV range calculator
- Egg RNG search for Emerald and FireRed/LeafGreen
- Localized UI in English, Japanese, Simplified Chinese, and Traditional Chinese
- Localized Gen 3 species, ability, nature, and location names
- Per-game local persistence for TID, SID, default seed, saved targets, and egg
  settings

Primary platform targets are iOS, iPadOS, and macOS. Android and Windows are
also kept buildable when possible.

## What This Project Does Not Include

This repository does not include ROMs, save files, official sprites, official
artwork, or other game assets. The app uses original UI assets and structured
RNG/encounter data needed for calculation.

## Basic Concepts

- `TID` / `SID`: Trainer ID and Secret ID. They determine shiny results.
- `Seed`: The starting RNG state. Emerald retail RNG normally starts from
  `00000000` after reset.
- `Frame`: Also called `advance` in many RNG tools. One frame is one RNG step
  in the search result list.
- `Press`: The frame where the player should perform the action after applying
  delay or calibration.
- `PID`: Personality value. It determines nature, ability slot, gender, and
  shiny status together with TID/SID.
- `IV`: Individual values, from 0 to 31.
- `Slot`: The encounter table slot. Different slots map to different species
  and levels for each location and encounter method.
- `Method 1 / 2 / 4`: Gen 3 Pokemon generation methods. Normal Emerald wild and
  static workflows usually use Method 1, but the app exposes the variants for
  comparison and edge cases.
- `Redraw`: Egg RNG redraw count. In Emerald this is commonly affected by
  opening and closing the Pokedex in the egg workflow.

## Emerald Retail Guide

This guide is intentionally limited to Emerald retail hardware. Emulator users
usually have a visible frame counter and can use the same search/calibration
results without relying on the built-in timer.

### 1. Enter Save Information

Open `Settings`.

1. Select `Emerald`.
2. Enter your `TID`.
3. Enter your `SID`.
4. Keep the default seed as `00000000` for Emerald retail RNG.

TID and SID are saved separately for each game version.

### 2. Search a Target

Open the search page.

1. Type a Pokemon name or National Dex number.
2. Pick a legal location from the location dropdown.
3. Pick the encounter method, such as grass, surfing, or rod.
4. Choose filters such as shiny, nature, ability, gender, Hidden Power, and IV
   rules.
5. Keep the default result limit unless you need more rows.
6. Search.

For example, a simple shiny wild search is:

- Game: Emerald
- Seed: `00000000`
- Species: target Pokemon
- Location: target route or cave
- Encounter: grass/surfing/rod as needed
- Shiny: yes
- Max frame: large enough to find usable results

The result card shows the frame, press frame, slot, level, gender, nature,
Hidden Power, IVs, PID, and calculated stats.

### 3. Save or Send the Target to Calibration

Long-press a result on mobile, or right-click it on desktop.

- Use `Save target` to store it in the tools page.
- Use `Send to calibration` when you are ready to attempt the target.

Each game version keeps its own saved targets. Duplicate targets are rejected,
and each game stores up to 20 saved targets.

### 4. Use the Retail Timer

Open the calibration page from the target.

The timer is meant for Emerald retail RNG where the initial seed is fixed.

1. Confirm the target frame shown at the top.
2. Press the timer start button.
3. The app gives a 5-second preparation countdown.
4. The cue has four beeps; soft reset or perform the target action on the
   fourth beep.
5. When the target countdown finishes, perform the encounter action on the
   fourth beep.

The timer keeps the screen awake while the calibration page is active.

### 5. Catch and Record the Actual Result

If the target misses, catch the Pokemon you actually encountered and enter:

- species
- level
- nature
- stats
- optional ability
- optional gender

The app converts stats back into possible IV ranges and searches the same RNG
area for matching frames. Pick the matching reverse-search row to fill the
actual frame.

### 6. Calculate the Next Target Frame

After the actual frame is filled, press the calibration button.

The first capture is mainly used to estimate the timing offset between the
target frame and the frame you actually hit. After that, the app gives a new
target frame for the next attempt. The second and later attempts are the real
capture attempts: if the offset is still large, adjust with the newly calculated
frame; if the offset is already very small, repeated attempts or small manual
tweaks may be enough.

## Static Targets

Static, gift, legendary, event, and roamer targets are searched from the same
main search page. Choose the static target from the location/target dropdown,
then apply the same filters.

Static results can also be saved or sent to calibration. The same timer and
calibration page can be used, treating the input timing as the delay to adjust.

## Egg RNG

Egg RNG is handled on its own page because the workflow uses different inputs:

- parent species and IVs
- daycare compatibility
- egg generation frame
- egg pickup frame
- redraw range
- method for Emerald or FireRed/LeafGreen

Egg search can be expensive if both frame ranges are very large. Keep the
ranges narrow when possible, then expand after confirming the setup.

The egg RNG implementation is a Dart port of the relevant PokeFinder algorithm.
It has not been verified with real hardware results in this project yet, so use
egg results carefully and compare against known tools when possible. Very large
search ranges can also make the app slow or temporarily unresponsive,
especially on mobile devices.

Egg calibration history is intentionally not included yet; the page focuses on
searching usable egg targets.

## Tools

The tools page includes:

- saved target list
- stat calculator
- IV range calculator

The calculators use Gen 3 stat formulas. Later generations use different rules
for some mechanics and should be handled separately if added in the future.

## Development

Install Flutter, then fetch dependencies:

```sh
flutter pub get
```

Run the app on macOS:

```sh
flutter run -d macos
```

Run static analysis and tests:

```sh
flutter analyze
flutter test
```

Generate localization code after editing ARB files:

```sh
flutter gen-l10n
```

Build an Android release APK for arm64 devices:

```sh
flutter build apk --release --target-platform android-arm64
```

## Repository Notes

Local reference material, third-party source checkouts, build outputs, signing
keys, provisioning profiles, and IDE user state should not be committed.

Before pushing, a useful check is:

```sh
git status --short
git ls-files
```

## License

This project is licensed under GPL-3.0-only.

See [LICENSE](LICENSE) for the full license text.

## Privacy

See [PRIVACY.md](PRIVACY.md).

## Credits

- Admiral-Fish and the PokeFinder contributors for
  [PokeFinder](https://github.com/Admiral-Fish/PokeFinder)
- DasAmpharos and the EonTimer contributors for
  [EonTimer](https://github.com/DasAmpharos/EonTimer)
- The PokemonRNG team for Gen 3 RNG guides and research
