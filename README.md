# PokeRNG G3

PokeRNG G3 is a Flutter/Dart RNG tool focused on Pokemon FireRed, LeafGreen,
and Emerald.

The goal is a compact multi-platform app for the Gen 3 workflows that are most
useful on desktop and mobile: wild encounters, static encounters, calibration,
saved targets, stat/IV calculation, and egg RNG.

## Platform Targets

Primary targets:

- macOS
- iOS

Secondary targets:

- Windows
- Android

## Current Scope

- Gen 3 LCRNG and Pokemon attribute helpers.
- Wild encounter search for FireRed, LeafGreen, and Emerald.
- Static, gift, legendary, event, and roamer search.
- Wild/static calibration from observed results.
- Saved targets per game version.
- Gen 3 stat and IV calculator.
- Egg RNG search for Emerald and FireRed/LeafGreen.
- Localized app UI plus Gen 3 species, ability, nature, and location names.
- Per-game profile persistence for TID, SID, seed, saved targets, and egg
  settings.

## Development

Run the standard checks:

```sh
flutter analyze
flutter test
```

Run the app on macOS:

```sh
flutter run -d macos
```

Generate localization code after editing ARB files:

```sh
flutter gen-l10n
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
