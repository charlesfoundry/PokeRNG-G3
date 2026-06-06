import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/profile.dart';
import 'core/gen3/gen3.dart';
import 'data/gen3/location_names.dart';
import 'data/gen3/named_resources.dart';
import 'data/gen3/personal_data.dart';
import 'data/gen3/static_encounter_repository.dart';
import 'data/gen3/static_encounters.dart';
import 'data/gen3/wild_encounter_repository.dart';
import 'data/gen3/wild_encounters.dart';
import 'l10n/app_localizations.dart';

const _maxSearchAdvanceDelta = 10000000;
const _maxEggAdvanceDelta = 10000;
const _maxDisplayedResults = 500;
const _maxSpeciesSuggestions = 50;
const _maxSavedTargets = 20;
const _projectUrl = 'https://github.com/charlesfoundry/PokeRNG-G3';
const _privacyPolicyUrl =
    'https://github.com/charlesfoundry/PokeRNG-G3/blob/main/PRIVACY.md';
const _appLicense = 'GPL-3.0-only';
final _largeEggSearchCombinationThreshold = BigInt.from(50000000);
const _retailTimerPreparation = Duration(seconds: 5);
const _retailTimerCueLead = Duration(milliseconds: 1500);
const _timerBeepChannel = MethodChannel('pokerng_g3/timer_beep');
const _screenAwakeChannel = MethodChannel('pokerng_g3/screen_awake');
const _supportPurchaseChannel = MethodChannel('pokerng_g3/support_purchase');
const _supportProductIds = [
  'pokerngg3.support.snack',
  'pokerngg3.support.coffee',
  'pokerngg3.support.meal',
];
const _gbaFrameRate = 16777216 / 280896;
const _ndsSlot2FrameRate = 59.6555;
const _ndsFamilyFrameRate = 59.8261;
const _controlRadius = 12.0;
const _controlBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(_controlRadius)),
  borderSide: BorderSide(color: Color(0xffd1d1d6)),
);

enum _LeadMode {
  none,
  pressure,
  synchronize,
  staticLead,
  magnetPull,
  cuteCharmFemale,
  cuteCharmMale,
}

enum _RetailTimerConsole { gba, ndsSlot2, ndsFamily }

enum _RetailTimerPhase { idle, preparation, target, finished }

enum _AppLanguage {
  system,
  zhHans,
  en,
  ja;

  Locale? get locale {
    return switch (this) {
      _AppLanguage.system => null,
      _AppLanguage.zhHans => const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      _AppLanguage.en => const Locale('en'),
      _AppLanguage.ja => const Locale('ja'),
    };
  }

  String get jsonName {
    return switch (this) {
      _AppLanguage.system => 'system',
      _AppLanguage.zhHans => 'zh_Hans',
      _AppLanguage.en => 'en',
      _AppLanguage.ja => 'ja',
    };
  }
}

String _areaKey(WildEncounterArea area) {
  return 'wild:${area.game.jsonName}:${area.locationId}:${area.type.jsonName}';
}

String _staticTemplateKey(StaticEncounterTemplate template) {
  return 'static:${template.game.jsonName}:${template.type.jsonName}:'
      '${template.species}:${template.level}:${template.description}';
}

class _WildSearchIsolateMessage {
  const _WildSearchIsolateMessage({
    required this.sendPort,
    required this.request,
  });

  final SendPort sendPort;
  final WildSearchRequest request;
}

class _StaticSearchIsolateMessage {
  const _StaticSearchIsolateMessage({
    required this.sendPort,
    required this.request,
  });

  final SendPort sendPort;
  final StaticSearchRequest request;
}

class _WildSearchIsolateFailure {
  const _WildSearchIsolateFailure(this.error);

  final String error;
}

void _runStaticSearchIsolate(_StaticSearchIsolateMessage message) {
  try {
    final request = message.request;
    final results = <StaticSearchHit>[];
    var resultLimitReached = false;
    var scanned = 0;
    final total = request.maxAdvance - request.initialAdvance + 1;
    for (final state in request.createGenerator().generate()) {
      scanned += 1;
      if (scanned == 1 || scanned % 100000 == 0) {
        message.sendPort.send(
          _WildSearchIsolateProgress(scanned: scanned, total: total),
        );
      }
      if (!request.matches(state)) {
        continue;
      }
      final hit = StaticSearchHit(template: request.template, state: state);
      results.add(hit);
      if (results.length >= request.resultLimit) {
        resultLimitReached = true;
        break;
      }
    }
    message.sendPort.send(
      _WildSearchIsolateProgress(scanned: total, total: total),
    );
    message.sendPort.send(
      StaticSearchResult(
        results: List<StaticSearchHit>.unmodifiable(results),
        resultLimitReached: resultLimitReached,
      ),
    );
  } catch (error) {
    message.sendPort.send(_WildSearchIsolateFailure(error.toString()));
  }
}

class _WildSearchIsolateProgress {
  const _WildSearchIsolateProgress({
    required this.scanned,
    required this.total,
  });

  final int scanned;
  final int total;

  double get fraction {
    if (total <= 0) {
      return 0;
    }
    return (scanned / total).clamp(0, 1);
  }
}

void _runWildSearchIsolate(_WildSearchIsolateMessage message) {
  try {
    final request = message.request;
    final results = <WildState>[];
    var resultLimitReached = false;
    var scanned = 0;
    final total = request.maxAdvance - request.initialAdvance + 1;
    for (final state in request.createGenerator().generate()) {
      scanned += 1;
      if (scanned == 1 || scanned % 100000 == 0) {
        message.sendPort.send(
          _WildSearchIsolateProgress(scanned: scanned, total: total),
        );
      }
      if (!request.matches(state)) {
        continue;
      }
      results.add(state);
      if (results.length >= request.resultLimit) {
        resultLimitReached = true;
        break;
      }
    }
    message.sendPort.send(
      _WildSearchIsolateProgress(scanned: total, total: total),
    );
    message.sendPort.send(
      WildSearchResult(
        results: List<WildState>.unmodifiable(results),
        resultLimitReached: resultLimitReached,
      ),
    );
  } catch (error) {
    message.sendPort.send(_WildSearchIsolateFailure(error.toString()));
  }
}

void main() {
  runApp(const PokeRngG3App());
}

class PokeRngG3App extends StatefulWidget {
  const PokeRngG3App({super.key});

  @override
  State<PokeRngG3App> createState() => _PokeRngG3AppState();
}

class _PokeRngG3AppState extends State<PokeRngG3App> {
  final _storage = _AppStorage();
  final Map<GameVersion, AppProfile> _profiles = {};
  AppProfile _profile = AppProfile.initial();
  _AppLanguage _language = _AppLanguage.system;
  int _shellEpoch = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  Future<void> _loadAppState() async {
    final profiles = await _storage.loadProfiles();
    final currentGame = await _storage.loadCurrentGame();
    final language = await _storage.loadLanguage();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles
        ..clear()
        ..addAll(profiles);
      _profile = profiles[currentGame] ?? profiles[GameVersion.emerald]!;
      _language = language;
      _loaded = true;
    });
  }

  void _setProfile(AppProfile profile) {
    setState(() {
      _profile = profile;
      _profiles[profile.game] = profile;
    });
    _storage.saveCurrentGame(profile.game);
    _storage.saveProfile(profile);
  }

  void _setLanguage(_AppLanguage language) {
    if (_language == language) {
      return;
    }
    setState(() {
      _language = language;
      _shellEpoch += 1;
    });
    _storage.saveLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: _language.locale,
      localeListResolutionCallback: _resolveAppLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(0.95)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7f7fa),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff007aff),
          primary: const Color(0xff007aff),
          secondary: const Color(0xff5856d6),
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xfff7f7fa),
          outline: const Color(0xffc7c7cc),
          outlineVariant: const Color(0xffd1d1d6),
        ),
        visualDensity: VisualDensity.compact,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hoverColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: _controlBorder,
          enabledBorder: _controlBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(_controlRadius)),
            borderSide: BorderSide(color: Color(0xff007aff), width: 1.4),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfff7f7fa),
          surfaceTintColor: Color(0xffe5e5ea),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xffd1d1d6),
          thickness: 1,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xff007aff),
            disabledBackgroundColor: const Color(0xfff7f7fa),
            disabledForegroundColor: const Color(0xff8e8e93),
            minimumSize: const Size(0, 42),
            side: const BorderSide(color: Color(0xffd1d1d6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_controlRadius),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xffffffff);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xff007aff);
            }
            return const Color(0xffd1d1d6);
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xff007aff);
            }
            return Colors.white;
          }),
          checkColor: const WidgetStatePropertyAll(Colors.white),
          side: const BorderSide(color: Color(0xffc7c7cc)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xff007aff),
            selectedBackgroundColor: const Color(0xffe5f1ff),
            selectedForegroundColor: const Color(0xff007aff),
            side: const BorderSide(color: Color(0xffd1d1d6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_controlRadius),
            ),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xff007aff),
          linearTrackColor: Color(0xffe5e5ea),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xfff7f7fa),
          indicatorColor: Color(0xffe5f1ff),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xffe5f1ff),
          elevation: 4,
        ),
        chipTheme: const ChipThemeData(
          shape: StadiumBorder(side: BorderSide(color: Color(0xffd1d1d6))),
          backgroundColor: Colors.white,
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          horizontalTitleGap: 8,
          minLeadingWidth: 28,
        ),
      ),
      home: _loaded
          ? _AppShell(
              key: ValueKey('app-shell-$_shellEpoch'),
              profile: _profile,
              profiles: Map.unmodifiable(_profiles),
              storage: _storage,
              onProfileChanged: _setProfile,
              language: _language,
              onLanguageChanged: _setLanguage,
            )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    super.key,
    required this.profile,
    required this.profiles,
    required this.storage,
    required this.onProfileChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppProfile profile;
  final Map<GameVersion, AppProfile> profiles;
  final _AppStorage storage;
  final ValueChanged<AppProfile> onProfileChanged;
  final _AppLanguage language;
  final ValueChanged<_AppLanguage> onLanguageChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final _huntKey = GlobalKey<_HuntPageState>();
  int _selectedIndex = 0;
  _HuntSearchSnapshot? _huntSearch;
  _CalibrationPageTarget? _calibrationTarget;
  final List<_SavedTarget> _savedTargets = [];
  _HuntResultsSnapshot _huntResults = const _HuntResultsSnapshot();
  GameVersion? _loadedTargetsGame;
  String? _loadedTargetsLocale;
  int _targetLoadEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedTargetsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.game != widget.profile.game) {
      _huntSearch = null;
      _calibrationTarget = null;
      _huntResults = const _HuntResultsSnapshot();
      _savedTargets.clear();
    }
    _loadSavedTargetsIfNeeded(
      force: oldWidget.profile.game != widget.profile.game,
    );
  }

  void _loadSavedTargetsIfNeeded({bool force = false}) {
    final localeName = Localizations.localeOf(context).toString();
    final game = widget.profile.game;
    if (!force &&
        _loadedTargetsGame == game &&
        _loadedTargetsLocale == localeName) {
      return;
    }
    _loadedTargetsGame = game;
    _loadedTargetsLocale = localeName;
    final epoch = _targetLoadEpoch + 1;
    _targetLoadEpoch = epoch;
    _loadSavedTargets(epoch: epoch, game: game, localeName: localeName);
  }

  Future<void> _loadSavedTargets({
    required int epoch,
    required GameVersion game,
    required String localeName,
  }) async {
    final data = await _HuntData.load(localeName);
    final records = await widget.storage.loadTargets(game);
    if (!mounted || epoch != _targetLoadEpoch) {
      return;
    }
    setState(() {
      _savedTargets
        ..clear()
        ..addAll(
          records
              .map((record) => record.toSavedTarget(data))
              .whereType<_SavedTarget>()
              .take(_maxSavedTargets),
        );
    });
  }

  void _saveTarget(_SavedTarget target) {
    final l10n = AppLocalizations.of(context)!;
    final duplicate = _savedTargets.any(
      (saved) => saved.duplicateKey == target.duplicateKey,
    );
    if (duplicate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.targetAlreadySaved)));
      return;
    }

    setState(() {
      _savedTargets.insert(0, target);
      if (_savedTargets.length > _maxSavedTargets) {
        _savedTargets.removeRange(_maxSavedTargets, _savedTargets.length);
      }
    });
    widget.storage.saveTargets(widget.profile.game, _savedTargets);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.targetSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final pages = [
      _HuntPage(
        key: _huntKey,
        profile: widget.profile,
        onResultsChanged: (results) {
          setState(() {
            _huntResults = results;
            if (!results.searching) {
              _huntSearch = results.search;
            }
            _selectedIndex = 1;
          });
        },
      ),
      _ResultsPage(
        snapshot: _huntResults,
        onCancelSearch: () => _huntKey.currentState?._cancelSearch(),
        onSendToCalibration: (target) {
          setState(() {
            _huntSearch = target.search;
            _calibrationTarget = target;
            _selectedIndex = 2;
          });
        },
        onSaveTarget: (target) {
          _saveTarget(
            _SavedCalibrationTarget(
              id: DateTime.now().microsecondsSinceEpoch,
              target: target,
              savedAt: DateTime.now(),
            ),
          );
        },
        onSaveStaticTarget: (target) {
          _saveTarget(
            _SavedStaticTarget(
              id: DateTime.now().microsecondsSinceEpoch,
              target: target,
              savedAt: DateTime.now(),
            ),
          );
        },
        onSendStaticToCalibration: (target) {
          setState(() {
            _calibrationTarget = target;
            _selectedIndex = 2;
          });
        },
      ),
      _CalibratePage(
        profile: widget.profile,
        search: _huntSearch,
        target: _calibrationTarget,
        active: _selectedIndex == 2,
      ),
      _BreedingPage(profile: widget.profile, storage: widget.storage),
      _ToolsPage(
        savedTargets: _savedTargets,
        onUseTarget: (saved) {
          setState(() {
            if (saved is _SavedCalibrationTarget) {
              _huntSearch = saved.target.search;
              _calibrationTarget = saved.target;
            } else if (saved is _SavedStaticTarget) {
              _calibrationTarget = saved.target;
            }
            _selectedIndex = 2;
          });
        },
        onDeleteTarget: (saved) {
          setState(() {
            _savedTargets.removeWhere((target) => target.id == saved.id);
          });
          widget.storage.saveTargets(widget.profile.game, _savedTargets);
        },
      ),
      _SettingsPage(
        profile: widget.profile,
        profiles: widget.profiles,
        onProfileChanged: widget.onProfileChanged,
        language: widget.language,
        onLanguageChanged: widget.onLanguageChanged,
      ),
    ];
    final pageStack = IndexedStack(index: _selectedIndex, children: pages);

    return _KeyboardDismissRegion(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: Text(
                  '${widget.profile.game.label} · ${widget.profile.tid}/${widget.profile.sid}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.search),
                          label: Text(l10n.hunt),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.list_alt),
                          label: Text(l10n.results),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.tune),
                          label: Text(l10n.calibrate),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.egg_alt_outlined),
                          label: Text(l10n.breeding),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.build),
                          label: Text(l10n.tools),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.settings),
                          label: Text(l10n.settings),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pageStack),
                  ],
                )
              : pageStack,
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.search),
                    label: l10n.hunt,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.list_alt),
                    label: l10n.results,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.tune),
                    label: l10n.calibrate,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.egg_alt_outlined),
                    label: l10n.breeding,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.build),
                    label: l10n.tools,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings),
                    label: l10n.settings,
                  ),
                ],
              ),
      ),
    );
  }
}

class _KeyboardDismissRegion extends StatelessWidget {
  const _KeyboardDismissRegion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: child,
    );
  }
}

class _HuntPage extends StatefulWidget {
  const _HuntPage({
    super.key,
    required this.profile,
    required this.onResultsChanged,
  });

  final AppProfile profile;
  final ValueChanged<_HuntResultsSnapshot> onResultsChanged;

  @override
  State<_HuntPage> createState() => _HuntPageState();
}

class _HuntPageState extends State<_HuntPage> {
  final _pokemonController = TextEditingController();
  final _pokemonFocusNode = FocusNode();
  final _seedController = TextEditingController(text: '00000000');
  final _initialAdvanceController = TextEditingController(text: '0');
  final _maxAdvanceController = TextEditingController(text: '100000');
  final _delayController = TextEditingController(text: '0');
  final _hpIvController = TextEditingController();
  final _attackIvController = TextEditingController();
  final _defenseIvController = TextEditingController();
  final _specialAttackIvController = TextEditingController();
  final _specialDefenseIvController = TextEditingController();
  final _speedIvController = TextEditingController();

  final _ivComparisons = List<IvComparison>.filled(
    6,
    IvComparison.greaterOrEqual,
  );
  Future<_HuntData>? _dataFuture;
  String? _localeName;
  int? _selectedSpeciesId;
  WildEncounterType? _encounterType;
  String? _locationKey;
  int? _abilitySlot;
  PokemonGender? _gender;
  int? _encounterSlot;
  HiddenPowerType? _hiddenPowerType;
  WildMethod _wildMethod = WildMethod.method1;
  _LeadMode _leadMode = _LeadMode.none;
  Nature _synchronizeNature = Nature.hardy;
  Nature? _nature;
  bool _feebasTile = false;
  bool _shinyOnly = false;
  int _searchEpoch = 0;
  bool _searching = false;
  Isolate? _searchIsolate;
  ReceivePort? _searchReceivePort;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seedController.text = widget.profile.defaultSeed;
    _wildMethod = _defaultWildMethodForGame(widget.profile.game);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = Localizations.localeOf(context).toString();
    if (_localeName != localeName) {
      _localeName = localeName;
      final dataFuture = _HuntData.load(localeName);
      _dataFuture = dataFuture;
      unawaited(
        dataFuture
            .then((data) {
              if (!mounted || _localeName != data.localeName) {
                return;
              }
              final selectedSpeciesId = _selectedSpeciesId;
              if (selectedSpeciesId != null) {
                _pokemonController.text = data.speciesDisplayName(
                  selectedSpeciesId,
                );
              } else {
                _refreshAutocompleteOptions(_pokemonController);
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _HuntPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.game != widget.profile.game) {
      _seedController.text = widget.profile.defaultSeed;
      _encounterType = null;
      _locationKey = null;
      _gender = null;
      _encounterSlot = null;
      _hiddenPowerType = null;
      _wildMethod = _defaultWildMethodForGame(widget.profile.game);
      _leadMode = _LeadMode.none;
      _feebasTile = false;
      _cancelSearch();
    }
  }

  @override
  void dispose() {
    _searchEpoch += 1;
    _stopSearchIsolate();
    _pokemonController.dispose();
    _pokemonFocusNode.dispose();
    _seedController.dispose();
    _initialAdvanceController.dispose();
    _maxAdvanceController.dispose();
    _delayController.dispose();
    _hpIvController.dispose();
    _attackIvController.dispose();
    _defenseIvController.dispose();
    _specialAttackIvController.dispose();
    _specialDefenseIvController.dispose();
    _speedIvController.dispose();
    super.dispose();
  }

  void _selectSpecies(_HuntData data, int speciesId) {
    final areas = data.areasForSpecies(
      game: widget.profile.game,
      speciesId: speciesId,
    );
    final staticTemplates = data.staticTemplatesForSpecies(
      game: widget.profile.game,
      speciesId: speciesId,
    );
    final types = data.encounterTypesForSpecies(
      game: widget.profile.game,
      speciesId: speciesId,
    );
    final nextType = types.isEmpty ? null : types.first;
    final nextAreas = nextType == null
        ? const <WildEncounterArea>[]
        : areas.where((area) => area.type == nextType).toList();
    final nextLocationKey = nextAreas.isNotEmpty
        ? _areaKey(nextAreas.first)
        : staticTemplates.isNotEmpty
        ? _staticTemplateKey(staticTemplates.first)
        : null;
    setState(() {
      _selectedSpeciesId = speciesId;
      _pokemonController.text = data.speciesDisplayName(speciesId);
      _encounterType = nextType;
      _locationKey = nextLocationKey;
      _abilitySlot = null;
      _gender = null;
      _encounterSlot = null;
      _wildMethod = _defaultMethodForLocation(nextLocationKey);
      _feebasTile = speciesId == 349;
    });
  }

  void _setEncounterType(_HuntData data, WildEncounterType? type) {
    final speciesId = _selectedSpeciesId;
    final areas = speciesId == null || type == null
        ? const <WildEncounterArea>[]
        : data
              .areasForSpecies(game: widget.profile.game, speciesId: speciesId)
              .where((area) => area.type == type)
              .toList();
    setState(() {
      _encounterType = type;
      _locationKey = areas.isEmpty ? null : _areaKey(areas.first);
      _encounterSlot = null;
      _wildMethod = _defaultWildMethodForGame(widget.profile.game);
      _leadMode = _LeadMode.none;
    });
  }

  WildMethod _defaultMethodForLocation(String? locationKey) {
    if (locationKey?.startsWith('static:') ?? false) {
      return WildMethod.method1;
    }
    return _defaultWildMethodForGame(widget.profile.game);
  }

  void _stopSearchIsolate() {
    _searchIsolate?.kill(priority: Isolate.immediate);
    _searchIsolate = null;
    _searchReceivePort?.close();
    _searchReceivePort = null;
  }

  void _cancelSearch() {
    if (!_searching) {
      return;
    }
    _searchEpoch += 1;
    _stopSearchIsolate();
    setState(() => _searching = false);
    widget.onResultsChanged(
      _HuntResultsSnapshot(
        error: AppLocalizations.of(context)!.searchCancelled,
      ),
    );
  }

  Future<void> _runSearch(_HuntData data) async {
    if (_searching) {
      _cancelSearch();
      return;
    }
    final parsed = _parseInputs();
    if (parsed == null) {
      widget.onResultsChanged(
        _HuntResultsSnapshot(error: _error, names: data.names),
      );
      return;
    }
    final targetSpeciesId = _selectedSpeciesId;
    final selectedArea = _selectedArea(data);
    final selectedStaticTemplate = _selectedStaticTemplate(data);
    if (targetSpeciesId == null ||
        (selectedArea == null && selectedStaticTemplate == null)) {
      final error = AppLocalizations.of(
        context,
      )!.selectPokemonEncounterLocationError;
      setState(() {
        _error = error;
      });
      widget.onResultsChanged(
        _HuntResultsSnapshot(error: error, names: data.names),
      );
      return;
    }

    if (selectedStaticTemplate != null) {
      await _runStaticSearch(
        data: data,
        parsed: parsed,
        template: selectedStaticTemplate,
      );
      return;
    }

    if (selectedArea == null) {
      return;
    }

    final leadMode = _effectiveLeadMode(
      leadMode: _leadMode,
      area: selectedArea,
      personalData: data.personal,
      targetPersonal: data.personal[targetSpeciesId],
    );
    final syncNature = leadMode == _LeadMode.synchronize
        ? _synchronizeNature
        : null;
    final pressureLead = leadMode == _LeadMode.pressure;
    final staticLead = leadMode == _LeadMode.staticLead;
    final magnetPullLead = leadMode == _LeadMode.magnetPull;
    final cuteCharmLead = _cuteCharmLead(leadMode);
    final feebasTile = _feebasTile && _isFeebasArea(selectedArea);
    final request = WildSearchRequest(
      seed: parsed.seed,
      initialAdvance: parsed.initialAdvance,
      maxAdvance: parsed.maxAdvance,
      delay: parsed.delay,
      method: _wildMethod,
      area: selectedArea,
      tid: widget.profile.tid,
      sid: widget.profile.sid,
      speciesId: targetSpeciesId,
      ivFilter: parsed.ivFilter,
      personalData: data.personal,
      resultLimit: _maxDisplayedResults,
      shinyOnly: _shinyOnly,
      nature: _nature,
      hiddenPowerType: _hiddenPowerType,
      abilitySlot: _abilitySlot,
      gender: _gender,
      encounterSlot: _encounterSlot,
      synchronizeNature: syncNature,
      pressureLead: pressureLead,
      staticLead: staticLead,
      magnetPullLead: magnetPullLead,
      cuteCharmLead: cuteCharmLead,
      feebasTile: feebasTile,
    );

    final searchSnapshot = _HuntSearchSnapshot(
      seed: parsed.seed,
      initialAdvance: parsed.initialAdvance,
      maxAdvance: parsed.maxAdvance,
      delay: parsed.delay,
      ivFilter: parsed.ivFilter,
      shinyOnly: request.shinyOnly,
      nature: request.nature,
      hiddenPowerType: request.hiddenPowerType,
      abilitySlot: request.abilitySlot,
      gender: request.gender,
      encounterSlot: request.encounterSlot,
      synchronizeNature: syncNature,
      pressureLead: pressureLead,
      staticLead: staticLead,
      magnetPullLead: magnetPullLead,
      cuteCharmLead: cuteCharmLead,
      feebasTile: feebasTile,
      speciesId: targetSpeciesId,
      area: selectedArea,
      method: _wildMethod,
      personalData: data.personal,
    );

    setState(() {
      _error = null;
    });
    final epoch = _searchEpoch + 1;
    _searchEpoch = epoch;
    setState(() => _searching = true);
    widget.onResultsChanged(
      _HuntResultsSnapshot(
        names: data.names,
        search: searchSnapshot,
        searching: true,
        delay: parsed.delay,
        searchProgress: 0,
      ),
    );

    if (kIsWeb) {
      try {
        final searchResult = request.search();
        if (!mounted || epoch != _searchEpoch) {
          return;
        }
        setState(() {
          _searching = false;
          _error = null;
        });
        widget.onResultsChanged(
          _HuntResultsSnapshot(
            names: data.names,
            search: searchSnapshot,
            delay: parsed.delay,
            results: searchResult.results
                .map(_HuntResult.wild)
                .toList(growable: false),
            resultLimitReached: searchResult.resultLimitReached,
          ),
        );
      } catch (error) {
        if (!mounted || epoch != _searchEpoch) {
          return;
        }
        setState(() {
          _searching = false;
          _error = error.toString();
        });
        widget.onResultsChanged(
          _HuntResultsSnapshot(error: error.toString(), names: data.names),
        );
      }
      return;
    }

    final receivePort = ReceivePort();
    _searchReceivePort = receivePort;
    Isolate? isolate;
    Object? response;
    try {
      isolate = await Isolate.spawn(
        _runWildSearchIsolate,
        _WildSearchIsolateMessage(
          sendPort: receivePort.sendPort,
          request: request,
        ),
        debugName: 'wild-search',
      );
      if (!mounted || epoch != _searchEpoch) {
        isolate.kill(priority: Isolate.immediate);
        return;
      }
      _searchIsolate = isolate;
      await for (final message in receivePort) {
        if (!mounted || epoch != _searchEpoch) {
          return;
        }
        if (message is _WildSearchIsolateProgress) {
          widget.onResultsChanged(
            _HuntResultsSnapshot(
              names: data.names,
              search: searchSnapshot,
              searching: true,
              delay: parsed.delay,
              searchProgress: message.fraction,
            ),
          );
          continue;
        }
        response = message;
        break;
      }
    } catch (error) {
      if (!mounted || epoch != _searchEpoch) {
        return;
      }
      setState(() {
        _searching = false;
        _error = error.toString();
      });
      widget.onResultsChanged(
        _HuntResultsSnapshot(error: error.toString(), names: data.names),
      );
      return;
    } finally {
      if (identical(_searchIsolate, isolate)) {
        _searchIsolate = null;
      }
      if (identical(_searchReceivePort, receivePort)) {
        _searchReceivePort = null;
      }
      receivePort.close();
    }

    if (!mounted || epoch != _searchEpoch) {
      return;
    }
    if (response is _WildSearchIsolateFailure) {
      final error = response.error;
      setState(() {
        _searching = false;
        _error = error;
      });
      widget.onResultsChanged(
        _HuntResultsSnapshot(error: error, names: data.names),
      );
      return;
    }
    final searchResult = response as WildSearchResult;
    setState(() {
      _searching = false;
      _error = null;
    });
    widget.onResultsChanged(
      _HuntResultsSnapshot(
        names: data.names,
        search: searchSnapshot,
        delay: parsed.delay,
        results: searchResult.results
            .map(_HuntResult.wild)
            .toList(growable: false),
        resultLimitReached: searchResult.resultLimitReached,
      ),
    );
  }

  Future<void> _runStaticSearch({
    required _HuntData data,
    required _ParsedHuntInputs parsed,
    required StaticEncounterTemplate template,
  }) async {
    final request = StaticSearchRequest(
      seed: parsed.seed,
      initialAdvance: parsed.initialAdvance,
      maxAdvance: parsed.maxAdvance,
      delay: parsed.delay,
      method: _staticMethodFor(_wildMethod),
      template: template,
      tid: widget.profile.tid,
      sid: widget.profile.sid,
      ivFilter: parsed.ivFilter,
      personalData: data.personal,
      resultLimit: _maxDisplayedResults,
      shinyOnly: _shinyOnly,
      nature: _nature,
      hiddenPowerType: _hiddenPowerType,
      abilitySlot: _abilitySlot,
      gender: _gender,
    );
    final searchSnapshot = _StaticSearchSnapshot(
      seed: parsed.seed,
      initialAdvance: parsed.initialAdvance,
      maxAdvance: parsed.maxAdvance,
      delay: parsed.delay,
      method: _staticMethodFor(_wildMethod),
      template: template,
      personalData: data.personal,
    );

    setState(() {
      _error = null;
    });
    final epoch = _searchEpoch + 1;
    _searchEpoch = epoch;
    setState(() => _searching = true);
    widget.onResultsChanged(
      _HuntResultsSnapshot(
        names: data.names,
        staticSearch: searchSnapshot,
        searching: true,
        delay: parsed.delay,
        searchProgress: 0,
      ),
    );

    if (kIsWeb) {
      try {
        final searchResult = request.search();
        if (!mounted || epoch != _searchEpoch) {
          return;
        }
        setState(() {
          _searching = false;
          _error = null;
        });
        widget.onResultsChanged(
          _HuntResultsSnapshot(
            names: data.names,
            staticSearch: searchSnapshot,
            delay: parsed.delay,
            results: searchResult.results
                .map(_HuntResult.static)
                .toList(growable: false),
            resultLimitReached: searchResult.resultLimitReached,
          ),
        );
      } catch (error) {
        if (!mounted || epoch != _searchEpoch) {
          return;
        }
        setState(() {
          _searching = false;
          _error = error.toString();
        });
        widget.onResultsChanged(
          _HuntResultsSnapshot(error: error.toString(), names: data.names),
        );
      }
      return;
    }

    final receivePort = ReceivePort();
    _searchReceivePort = receivePort;
    Isolate? isolate;
    Object? response;
    try {
      isolate = await Isolate.spawn(
        _runStaticSearchIsolate,
        _StaticSearchIsolateMessage(
          sendPort: receivePort.sendPort,
          request: request,
        ),
        debugName: 'static-search',
      );
      if (!mounted || epoch != _searchEpoch) {
        isolate.kill(priority: Isolate.immediate);
        return;
      }
      _searchIsolate = isolate;
      await for (final message in receivePort) {
        if (!mounted || epoch != _searchEpoch) {
          return;
        }
        if (message is _WildSearchIsolateProgress) {
          widget.onResultsChanged(
            _HuntResultsSnapshot(
              names: data.names,
              staticSearch: searchSnapshot,
              searching: true,
              delay: parsed.delay,
              searchProgress: message.fraction,
            ),
          );
          continue;
        }
        response = message;
        break;
      }
    } catch (error) {
      if (!mounted || epoch != _searchEpoch) {
        return;
      }
      setState(() {
        _searching = false;
        _error = error.toString();
      });
      widget.onResultsChanged(
        _HuntResultsSnapshot(error: error.toString(), names: data.names),
      );
      return;
    } finally {
      if (identical(_searchIsolate, isolate)) {
        _searchIsolate = null;
      }
      if (identical(_searchReceivePort, receivePort)) {
        _searchReceivePort = null;
      }
      receivePort.close();
    }

    if (!mounted || epoch != _searchEpoch) {
      return;
    }
    if (response is _WildSearchIsolateFailure) {
      final error = response.error;
      setState(() {
        _searching = false;
        _error = error;
      });
      widget.onResultsChanged(
        _HuntResultsSnapshot(error: error, names: data.names),
      );
      return;
    }
    final searchResult = response as StaticSearchResult;
    setState(() {
      _searching = false;
      _error = null;
    });
    widget.onResultsChanged(
      _HuntResultsSnapshot(
        names: data.names,
        staticSearch: searchSnapshot,
        delay: parsed.delay,
        results: searchResult.results
            .map(_HuntResult.static)
            .toList(growable: false),
        resultLimitReached: searchResult.resultLimitReached,
      ),
    );
  }

  WildEncounterArea? _selectedArea(_HuntData data) {
    final speciesId = _selectedSpeciesId;
    final locationKey = _locationKey;
    if (speciesId == null || locationKey == null) {
      return null;
    }
    for (final area in data.areasForSpecies(
      game: widget.profile.game,
      speciesId: speciesId,
    )) {
      if (_areaKey(area) == locationKey) {
        return area;
      }
    }
    return null;
  }

  StaticEncounterTemplate? _selectedStaticTemplate(_HuntData data) {
    final speciesId = _selectedSpeciesId;
    final locationKey = _locationKey;
    if (speciesId == null || locationKey == null) {
      return null;
    }
    for (final template in data.staticTemplatesForSpecies(
      game: widget.profile.game,
      speciesId: speciesId,
    )) {
      if (_staticTemplateKey(template) == locationKey) {
        return template;
      }
    }
    return null;
  }

  _ParsedHuntInputs? _parseInputs() {
    final seed = _parseHex(_seedController.text);
    final initialAdvance = int.tryParse(_initialAdvanceController.text.trim());
    final maxAdvance = int.tryParse(_maxAdvanceController.text.trim());
    final delay = int.tryParse(_delayController.text.trim());
    final ivFilter = _parseIvFilter();

    if (seed == null ||
        initialAdvance == null ||
        maxAdvance == null ||
        delay == null ||
        ivFilter == null ||
        initialAdvance < 0 ||
        maxAdvance < initialAdvance ||
        maxAdvance - initialAdvance > _maxSearchAdvanceDelta) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.huntInputError(_maxSearchAdvanceDelta);
      });
      return null;
    }

    return _ParsedHuntInputs(
      seed: seed,
      initialAdvance: initialAdvance,
      maxAdvance: maxAdvance,
      delay: delay,
      ivFilter: ivFilter,
    );
  }

  IvFilter? _parseIvFilter() {
    final values = [
      _parseOptionalIv(_hpIvController.text),
      _parseOptionalIv(_attackIvController.text),
      _parseOptionalIv(_defenseIvController.text),
      _parseOptionalIv(_specialAttackIvController.text),
      _parseOptionalIv(_specialDefenseIvController.text),
      _parseOptionalIv(_speedIvController.text),
    ];
    if (values.any((value) => value == null || value < -1 || value > 31)) {
      return null;
    }
    return IvFilter(
      rules: [
        for (var i = 0; i < values.length; i += 1)
          IvRule(value: values[i]!, comparison: _ivComparisons[i]),
      ],
    );
  }

  int? _parseOptionalIv(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return -1;
    }
    return int.tryParse(trimmed);
  }

  int? _parseHex(String value) {
    final normalized = value.trim().replaceFirst(RegExp('^0x'), '');
    if (normalized.isEmpty || normalized.length > 8) {
      return null;
    }
    return int.tryParse(normalized, radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    final dataFuture = _dataFuture;
    if (dataFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_HuntData>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              AppLocalizations.of(
                context,
              )!.failedLoadTargetData(snapshot.error.toString()),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final controls = _HuntControls(
          game: widget.profile.game,
          data: data,
          selectedSpeciesId: _selectedSpeciesId,
          encounterType: _encounterType,
          locationKey: _locationKey,
          abilitySlot: _abilitySlot,
          gender: _gender,
          encounterSlot: _encounterSlot,
          hiddenPowerType: _hiddenPowerType,
          wildMethod: _wildMethod,
          leadMode: _leadMode,
          synchronizeNature: _synchronizeNature,
          feebasTile: _feebasTile,
          pokemonController: _pokemonController,
          pokemonFocusNode: _pokemonFocusNode,
          seedController: _seedController,
          initialAdvanceController: _initialAdvanceController,
          maxAdvanceController: _maxAdvanceController,
          delayController: _delayController,
          hpIvController: _hpIvController,
          attackIvController: _attackIvController,
          defenseIvController: _defenseIvController,
          specialAttackIvController: _specialAttackIvController,
          specialDefenseIvController: _specialDefenseIvController,
          speedIvController: _speedIvController,
          ivComparisons: _ivComparisons,
          nature: _nature,
          shinyOnly: _shinyOnly,
          isSearching: _searching,
          onSpeciesSelected: (speciesId) => _selectSpecies(data, speciesId),
          onEncounterTypeChanged: (value) => _setEncounterType(data, value),
          onLocationChanged: (value) {
            setState(() {
              _locationKey = value;
              _encounterSlot = null;
              _wildMethod = _defaultMethodForLocation(value);
              _leadMode = _LeadMode.none;
            });
          },
          onAbilitySlotChanged: (value) => setState(() => _abilitySlot = value),
          onGenderChanged: (value) => setState(() => _gender = value),
          onEncounterSlotChanged: (value) {
            setState(() => _encounterSlot = value);
          },
          onHiddenPowerTypeChanged: (value) {
            setState(() => _hiddenPowerType = value);
          },
          onIvComparisonChanged: (index, value) {
            setState(() => _ivComparisons[index] = value);
          },
          onWildMethodChanged: (value) {
            setState(() => _wildMethod = value ?? WildMethod.method1);
          },
          onLeadModeChanged: (value) {
            setState(() => _leadMode = value ?? _LeadMode.none);
          },
          onSynchronizeNatureChanged: (value) {
            setState(() => _synchronizeNature = value ?? Nature.hardy);
          },
          onFeebasTileChanged: (value) => setState(() => _feebasTile = value),
          onNatureChanged: (nature) => setState(() => _nature = nature),
          onShinyChanged: (value) => setState(() => _shinyOnly = value),
          onSearch: () => _runSearch(data),
          onCancelSearch: _cancelSearch,
        );

        return controls;
      },
    );
  }
}

class _HuntControls extends StatelessWidget {
  const _HuntControls({
    required this.game,
    required this.data,
    required this.selectedSpeciesId,
    required this.encounterType,
    required this.locationKey,
    required this.abilitySlot,
    required this.gender,
    required this.encounterSlot,
    required this.hiddenPowerType,
    required this.wildMethod,
    required this.leadMode,
    required this.synchronizeNature,
    required this.feebasTile,
    required this.pokemonController,
    required this.pokemonFocusNode,
    required this.seedController,
    required this.initialAdvanceController,
    required this.maxAdvanceController,
    required this.delayController,
    required this.hpIvController,
    required this.attackIvController,
    required this.defenseIvController,
    required this.specialAttackIvController,
    required this.specialDefenseIvController,
    required this.speedIvController,
    required this.ivComparisons,
    required this.nature,
    required this.shinyOnly,
    required this.isSearching,
    required this.onSpeciesSelected,
    required this.onEncounterTypeChanged,
    required this.onLocationChanged,
    required this.onAbilitySlotChanged,
    required this.onGenderChanged,
    required this.onEncounterSlotChanged,
    required this.onHiddenPowerTypeChanged,
    required this.onIvComparisonChanged,
    required this.onWildMethodChanged,
    required this.onLeadModeChanged,
    required this.onSynchronizeNatureChanged,
    required this.onFeebasTileChanged,
    required this.onNatureChanged,
    required this.onShinyChanged,
    required this.onSearch,
    required this.onCancelSearch,
  });

  final GameVersion game;
  final _HuntData data;
  final int? selectedSpeciesId;
  final WildEncounterType? encounterType;
  final String? locationKey;
  final int? abilitySlot;
  final PokemonGender? gender;
  final int? encounterSlot;
  final HiddenPowerType? hiddenPowerType;
  final WildMethod wildMethod;
  final _LeadMode leadMode;
  final Nature synchronizeNature;
  final bool feebasTile;
  final TextEditingController pokemonController;
  final FocusNode pokemonFocusNode;
  final TextEditingController seedController;
  final TextEditingController initialAdvanceController;
  final TextEditingController maxAdvanceController;
  final TextEditingController delayController;
  final TextEditingController hpIvController;
  final TextEditingController attackIvController;
  final TextEditingController defenseIvController;
  final TextEditingController specialAttackIvController;
  final TextEditingController specialDefenseIvController;
  final TextEditingController speedIvController;
  final List<IvComparison> ivComparisons;
  final Nature? nature;
  final bool shinyOnly;
  final bool isSearching;
  final ValueChanged<int> onSpeciesSelected;
  final ValueChanged<WildEncounterType?> onEncounterTypeChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<int?> onAbilitySlotChanged;
  final ValueChanged<PokemonGender?> onGenderChanged;
  final ValueChanged<int?> onEncounterSlotChanged;
  final ValueChanged<HiddenPowerType?> onHiddenPowerTypeChanged;
  final void Function(int index, IvComparison value) onIvComparisonChanged;
  final ValueChanged<WildMethod?> onWildMethodChanged;
  final ValueChanged<_LeadMode?> onLeadModeChanged;
  final ValueChanged<Nature?> onSynchronizeNatureChanged;
  final ValueChanged<bool> onFeebasTileChanged;
  final ValueChanged<Nature?> onNatureChanged;
  final ValueChanged<bool> onShinyChanged;
  final VoidCallback onSearch;
  final VoidCallback onCancelSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedPersonal = selectedSpeciesId == null
        ? null
        : data.personal[selectedSpeciesId!];
    final areas = selectedSpeciesId == null
        ? const <WildEncounterArea>[]
        : data.areasForSpecies(game: game, speciesId: selectedSpeciesId!);
    final staticTemplates = selectedSpeciesId == null
        ? const <StaticEncounterTemplate>[]
        : data.staticTemplatesForSpecies(
            game: game,
            speciesId: selectedSpeciesId!,
          );
    final encounterTypes = selectedSpeciesId == null
        ? const <WildEncounterType>[]
        : data.encounterTypesForSpecies(
            game: game,
            speciesId: selectedSpeciesId!,
          );
    final selectedEncounterType = encounterTypes.contains(encounterType)
        ? encounterType
        : null;
    final locationAreas = selectedEncounterType == null
        ? areas
        : areas
              .where((area) => area.type == selectedEncounterType)
              .toList(growable: false);
    final locationKeys = {
      for (final area in locationAreas) _areaKey(area),
      for (final template in staticTemplates) _staticTemplateKey(template),
    };
    final selectedLocationKey =
        locationKey == null || !locationKeys.contains(locationKey)
        ? null
        : locationKey;
    final selectedArea = selectedLocationKey == null
        ? null
        : locationAreas
              .where((area) => _areaKey(area) == selectedLocationKey)
              .firstOrNull;
    final selectedStaticTemplate = selectedLocationKey == null
        ? null
        : staticTemplates
              .where(
                (template) =>
                    _staticTemplateKey(template) == selectedLocationKey,
              )
              .firstOrNull;
    final staticSelected = selectedStaticTemplate != null;
    final legalSlots = selectedArea == null || selectedSpeciesId == null
        ? const <int>[]
        : _slotsForSpecies(selectedArea, selectedSpeciesId!);
    final selectedSlot = legalSlots.contains(encounterSlot)
        ? encounterSlot
        : null;
    final legalGenders = _legalGenders(selectedPersonal);
    final selectedGender = legalGenders.contains(gender) ? gender : null;
    final feebasAvailable = selectedArea != null && _isFeebasArea(selectedArea);
    final availableLeadModes = staticSelected
        ? const [_LeadMode.none]
        : _availableLeadModes(
            area: selectedArea,
            personalData: data.personal,
            targetPersonal: selectedPersonal,
          );
    final selectedLeadMode = availableLeadModes.contains(leadMode)
        ? leadMode
        : _LeadMode.none;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.target, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _AutocompleteOptionsPrimer(
          controller: pokemonController,
          focusNode: pokemonFocusNode,
          token: data.localeName,
          child: RawAutocomplete<_SpeciesOption>(
            textEditingController: pokemonController,
            focusNode: pokemonFocusNode,
            displayStringForOption: (option) => option.displayName,
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();
              if (query.isEmpty) {
                return data.speciesOptions.take(_maxSpeciesSuggestions);
              }
              final numericStart = _numericSpeciesStart(query);
              if (numericStart != null) {
                if (numericStart > data.speciesOptions.length) {
                  return const Iterable<_SpeciesOption>.empty();
                }
                return data.speciesOptions
                    .skip(numericStart - 1)
                    .take(_maxSpeciesSuggestions);
              }
              return data.speciesOptions
                  .where((option) => option.searchText.contains(query))
                  .take(_maxSpeciesSuggestions);
            },
            onSelected: (option) => onSpeciesSelected(option.speciesId),
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    key: const ValueKey('pokemon-field'),
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: l10n.pokemon,
                      prefixIcon: const Icon(Icons.catching_pokemon),
                      border: _controlBorder,
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(_controlRadius),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 360,
                      maxHeight: 280,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(option.displayName),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (selectedSpeciesId == null)
          TextField(
            key: const ValueKey('location-disabled-field'),
            enabled: false,
            decoration: InputDecoration(
              labelText: l10n.locationEgg,
              prefixIcon: const Icon(Icons.map),
              border: _controlBorder,
            ),
          )
        else
          DropdownButtonFormField<String?>(
            key: ValueKey('location-$selectedSpeciesId-$selectedEncounterType'),
            isExpanded: true,
            initialValue: selectedLocationKey,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              labelText: l10n.locationEgg,
              prefixIcon: const Icon(Icons.map),
              border: _controlBorder,
            ),
            items: [
              ...locationAreas.map(
                (area) => DropdownMenuItem<String?>(
                  value: _areaKey(area),
                  child: Text(
                    data.locationLabel(context, area),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ...staticTemplates.map(
                (template) => DropdownMenuItem<String?>(
                  value: _staticTemplateKey(template),
                  child: Text(
                    data.staticTemplateLabel(context, template),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            selectedItemBuilder: (context) {
              final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              );
              return [
                ...locationAreas.map(
                  (area) => Text(
                    data.locationLabel(context, area),
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                ...staticTemplates.map(
                  (template) => Text(
                    data.staticTemplateLabel(context, template),
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ];
            },
            onChanged: onLocationChanged,
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(
            l10n.pokemonSearchLimitHint,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.encounter, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _ResponsiveFormGrid(
          children: [
            DropdownButtonFormField<WildEncounterType?>(
              isExpanded: true,
              key: ValueKey(
                'encounter-type-$selectedSpeciesId-$selectedEncounterType',
              ),
              initialValue: selectedEncounterType,
              decoration: InputDecoration(
                labelText: l10n.encounter,
                border: _controlBorder,
              ),
              items: [
                ...encounterTypes.map(
                  (type) => DropdownMenuItem<WildEncounterType?>(
                    value: type,
                    child: Text(
                      _encounterTypeLabel(context, type),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: selectedSpeciesId == null || encounterTypes.isEmpty
                  ? null
                  : onEncounterTypeChanged,
            ),
            DropdownButtonFormField<WildMethod>(
              isExpanded: true,
              initialValue: wildMethod,
              decoration: InputDecoration(
                labelText: l10n.method,
                border: _controlBorder,
              ),
              items: [
                DropdownMenuItem<WildMethod>(
                  value: WildMethod.method1,
                  child: Text(
                    staticSelected ? l10n.staticMethod1 : l10n.wildMethod1,
                  ),
                ),
                DropdownMenuItem<WildMethod>(
                  value: WildMethod.method2,
                  child: Text(
                    staticSelected ? l10n.staticMethod2 : l10n.wildMethod2,
                  ),
                ),
                DropdownMenuItem<WildMethod>(
                  value: WildMethod.method4,
                  child: Text(
                    staticSelected ? l10n.staticMethod4 : l10n.wildMethod4,
                  ),
                ),
              ],
              onChanged: onWildMethodChanged,
            ),
            DropdownButtonFormField<int?>(
              isExpanded: true,
              key: ValueKey('ability-$selectedSpeciesId-$abilitySlot'),
              initialValue: abilitySlot == 0 || abilitySlot == 1
                  ? abilitySlot
                  : null,
              decoration: InputDecoration(
                labelText: l10n.ability,
                border: _controlBorder,
              ),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(l10n.any)),
                if (selectedPersonal != null)
                  ...List<DropdownMenuItem<int?>>.generate(2, (slot) {
                    final id = selectedPersonal.abilityIds[slot];
                    return DropdownMenuItem<int?>(
                      value: slot,
                      child: Text(
                        _abilitySlotLabel(
                          context: context,
                          slot: slot,
                          name: data.names.abilityName(id),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
              ],
              onChanged: selectedPersonal == null ? null : onAbilitySlotChanged,
            ),
            DropdownButtonFormField<PokemonGender?>(
              isExpanded: true,
              key: ValueKey('gender-$selectedSpeciesId-$selectedGender'),
              initialValue: selectedGender,
              decoration: InputDecoration(
                labelText: l10n.gender,
                border: _controlBorder,
              ),
              items: [
                DropdownMenuItem<PokemonGender?>(
                  value: null,
                  child: Text(l10n.any),
                ),
                ...legalGenders.map(
                  (gender) => DropdownMenuItem<PokemonGender?>(
                    value: gender,
                    child: Text(_genderLabel(gender)),
                  ),
                ),
              ],
              onChanged: selectedPersonal == null ? null : onGenderChanged,
            ),
            DropdownButtonFormField<int?>(
              isExpanded: true,
              key: ValueKey(
                'slot-$selectedSpeciesId-$selectedLocationKey-$selectedSlot',
              ),
              initialValue: selectedSlot,
              decoration: InputDecoration(
                labelText: l10n.slot,
                border: _controlBorder,
              ),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(l10n.any)),
                ...legalSlots.map((slotIndex) {
                  final slot = selectedArea!.slots[slotIndex];
                  return DropdownMenuItem<int?>(
                    value: slotIndex,
                    child: Text(
                      '$slotIndex · ${l10n.levelShort} ${slot.minLevel}-${slot.maxLevel}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: legalSlots.isEmpty ? null : onEncounterSlotChanged,
            ),
            DropdownButtonFormField<_LeadMode>(
              isExpanded: true,
              key: ValueKey(
                'lead-$selectedSpeciesId-$selectedLocationKey-$selectedLeadMode',
              ),
              initialValue: selectedLeadMode,
              decoration: InputDecoration(
                labelText: l10n.lead,
                border: _controlBorder,
              ),
              items: [
                for (final mode in availableLeadModes)
                  DropdownMenuItem<_LeadMode>(
                    value: mode,
                    child: Text(_leadModeLabel(context, mode)),
                  ),
              ],
              onChanged: onLeadModeChanged,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(
            staticSelected
                ? l10n.staticMethodHint
                : game == GameVersion.emerald
                ? l10n.wildMethodHintEmerald
                : l10n.wildMethodHintFrlg,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (selectedLeadMode == _LeadMode.synchronize) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<Nature>(
            isExpanded: true,
            initialValue: synchronizeNature,
            decoration: InputDecoration(
              labelText: l10n.syncNature,
              prefixIcon: const Icon(Icons.sync),
              border: _controlBorder,
            ),
            items: Nature.values
                .map(
                  (value) => DropdownMenuItem<Nature>(
                    value: value,
                    child: Text(
                      data.natureLabel(context, value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onSynchronizeNatureChanged,
          ),
        ],
        if (feebasAvailable) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.feebasTile),
            secondary: const Icon(Icons.water),
            value: feebasTile,
            onChanged: onFeebasTileChanged,
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shiny),
          secondary: const Icon(Icons.auto_awesome),
          value: shinyOnly,
          onChanged: onShinyChanged,
        ),
        const SizedBox(height: 8),
        _ResponsiveFormGrid(
          children: [
            DropdownButtonFormField<Nature?>(
              isExpanded: true,
              initialValue: nature,
              decoration: InputDecoration(
                labelText: l10n.nature,
                border: _controlBorder,
              ),
              items: [
                DropdownMenuItem<Nature?>(value: null, child: Text(l10n.any)),
                ...Nature.values.map(
                  (value) => DropdownMenuItem<Nature?>(
                    value: value,
                    child: Text(
                      data.natureLabel(context, value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onNatureChanged,
            ),
            DropdownButtonFormField<HiddenPowerType?>(
              isExpanded: true,
              initialValue: hiddenPowerType,
              decoration: InputDecoration(
                labelText: l10n.hiddenPower,
                border: _controlBorder,
              ),
              items: [
                DropdownMenuItem<HiddenPowerType?>(
                  value: null,
                  child: Text(l10n.any),
                ),
                ...HiddenPowerType.values.map(
                  (value) => DropdownMenuItem<HiddenPowerType?>(
                    value: value,
                    child: Text(
                      _hiddenPowerTypeLabel(context, value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onHiddenPowerTypeChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _IvInputGrid(
          controllers: [
            hpIvController,
            attackIvController,
            defenseIvController,
            specialAttackIvController,
            specialDefenseIvController,
            speedIvController,
          ],
          comparisons: ivComparisons,
          onComparisonChanged: onIvComparisonChanged,
        ),
        const SizedBox(height: 6),
        Text(l10n.ivAnyNote, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.videogame_asset, label: game.label),
        const SizedBox(height: 14),
        Text(l10n.search, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _ResponsiveFormGrid(
          children: [
            TextField(
              controller: seedController,
              decoration: InputDecoration(
                labelText: l10n.seed,
                prefixIcon: const Icon(Icons.tag),
                border: _controlBorder,
              ),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: delayController,
              decoration: InputDecoration(
                labelText: l10n.delay,
                prefixIcon: const Icon(Icons.timer),
                border: _controlBorder,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isSearching) {
                  onSearch();
                }
              },
            ),
            TextField(
              controller: initialAdvanceController,
              decoration: InputDecoration(
                labelText: l10n.initialAdvance,
                prefixIcon: const Icon(Icons.first_page),
                border: _controlBorder,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: maxAdvanceController,
              decoration: InputDecoration(
                labelText: l10n.maxAdvance,
                prefixIcon: const Icon(Icons.last_page),
                border: _controlBorder,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.searchRangeNote(_maxSearchAdvanceDelta, _maxDisplayedResults),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isSearching ? onCancelSearch : onSearch,
            icon: isSearching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(isSearching ? l10n.cancelSearch : l10n.search),
          ),
        ),
      ],
    );
  }
}

class _HuntResults extends StatelessWidget {
  const _HuntResults({
    required this.error,
    required this.names,
    required this.search,
    required this.staticSearch,
    required this.delay,
    required this.results,
    required this.resultLimitReached,
    required this.searching,
    required this.searchProgress,
    required this.onCancelSearch,
    required this.onSendToCalibration,
    required this.onSaveTarget,
    required this.onSaveStaticTarget,
    required this.onSendStaticToCalibration,
  });

  final String? error;
  final Gen3NamedResources names;
  final _HuntSearchSnapshot? search;
  final _StaticSearchSnapshot? staticSearch;
  final int delay;
  final List<_HuntResult> results;
  final bool resultLimitReached;
  final bool searching;
  final double? searchProgress;
  final VoidCallback onCancelSearch;
  final ValueChanged<_CalibrationTarget> onSendToCalibration;
  final ValueChanged<_CalibrationTarget> onSaveTarget;
  final ValueChanged<_StaticTarget> onSaveStaticTarget;
  final ValueChanged<_StaticTarget> onSendStaticToCalibration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.results,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                resultLimitReached ? '${results.length}+' : '${results.length}',
              ),
            ],
          ),
        ),
        if (resultLimitReached)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.resultLimitNote(_maxDisplayedResults),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        if (searching) ...[
          LinearProgressIndicator(value: searchProgress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                if (searchProgress != null)
                  Text(
                    '${(searchProgress! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                const Spacer(),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onCancelSearch,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.cancelSearch),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: searching
              ? Center(child: Text(l10n.searching))
              : results.isEmpty
              ? Center(child: Text(l10n.noResults))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return switch (result) {
                      _WildHuntResult(:final state) => _ResultContextMenu(
                        enabled: search != null,
                        onSendToCalibration: search == null
                            ? null
                            : () => onSendToCalibration(
                                _CalibrationTarget(
                                  search: search!,
                                  state: state,
                                  names: names,
                                ),
                              ),
                        onSaveTarget: search == null
                            ? null
                            : () => onSaveTarget(
                                _CalibrationTarget(
                                  search: search!,
                                  state: state,
                                  names: names,
                                ),
                              ),
                        child: _WildResultTile(
                          state: state,
                          triggerAdvance: state.advance - delay,
                          natureName: names.natureName(state.nature),
                          personalData: search?.personalData,
                        ),
                      ),
                      _StaticHuntResult(:final hit) => _ResultContextMenu(
                        enabled: staticSearch != null,
                        onSendToCalibration: staticSearch == null
                            ? null
                            : () => onSendStaticToCalibration(
                                _StaticTarget(
                                  search: staticSearch!,
                                  hit: hit,
                                  names: names,
                                ),
                              ),
                        onSaveTarget: staticSearch == null
                            ? null
                            : () => onSaveStaticTarget(
                                _StaticTarget(
                                  search: staticSearch!,
                                  hit: hit,
                                  names: names,
                                ),
                              ),
                        child: _StaticResultTile(
                          hit: hit,
                          triggerAdvance: hit.state.advance - delay,
                          natureName: names.natureName(hit.state.nature),
                          personalData: staticSearch?.personalData,
                        ),
                      ),
                    };
                  },
                ),
        ),
      ],
    );
  }
}

class _ResultsPage extends StatelessWidget {
  const _ResultsPage({
    required this.snapshot,
    required this.onCancelSearch,
    required this.onSendToCalibration,
    required this.onSaveTarget,
    required this.onSaveStaticTarget,
    required this.onSendStaticToCalibration,
  });

  final _HuntResultsSnapshot snapshot;
  final VoidCallback onCancelSearch;
  final ValueChanged<_CalibrationTarget> onSendToCalibration;
  final ValueChanged<_CalibrationTarget> onSaveTarget;
  final ValueChanged<_StaticTarget> onSaveStaticTarget;
  final ValueChanged<_StaticTarget> onSendStaticToCalibration;

  @override
  Widget build(BuildContext context) {
    final names = snapshot.names;
    if (names == null) {
      return _HuntResultsPlaceholder(error: snapshot.error);
    }
    return _HuntResults(
      error: snapshot.error,
      names: names,
      search: snapshot.search,
      staticSearch: snapshot.staticSearch,
      delay: snapshot.delay,
      results: snapshot.results,
      resultLimitReached: snapshot.resultLimitReached,
      searching: snapshot.searching,
      searchProgress: snapshot.searchProgress,
      onCancelSearch: onCancelSearch,
      onSendToCalibration: onSendToCalibration,
      onSaveTarget: onSaveTarget,
      onSaveStaticTarget: onSaveStaticTarget,
      onSendStaticToCalibration: onSendStaticToCalibration,
    );
  }
}

class _HuntResultsPlaceholder extends StatelessWidget {
  const _HuntResultsPlaceholder({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.results,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Text('0'),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              l10n.selectAResult,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFormGrid extends StatelessWidget {
  const _ResponsiveFormGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 260 ? 2 : 1;
        final spacing = columns == 1 ? 0.0 : 6.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _ClearOnFirstFocusTextField extends StatefulWidget {
  const _ClearOnFirstFocusTextField({
    required this.controller,
    required this.decoration,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_ClearOnFirstFocusTextField> createState() =>
      _ClearOnFirstFocusTextFieldState();
}

class _ClearOnFirstFocusTextFieldState
    extends State<_ClearOnFirstFocusTextField> {
  final _focusNode = FocusNode();
  bool _clearOnFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && _clearOnFocus) {
      widget.controller.clear();
    }
    if (!_focusNode.hasFocus) {
      _clearOnFocus = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        _clearOnFocus = !_focusNode.hasFocus;
      },
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
      ),
    );
  }
}

class _IvInputGrid extends StatelessWidget {
  const _IvInputGrid({
    required this.controllers,
    required this.comparisons,
    required this.onComparisonChanged,
  });

  final List<TextEditingController> controllers;
  final List<IvComparison> comparisons;
  final void Function(int index, IvComparison value) onComparisonChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['HP IV', 'Atk IV', 'Def IV', 'SpA IV', 'SpD IV', 'Spe IV'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 500 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 64,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: controllers.length,
          itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: DropdownButtonFormField<IvComparison>(
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        key: ValueKey(
                          'iv-comparison-$index-${comparisons[index]}',
                        ),
                        initialValue: comparisons[index],
                        decoration: const InputDecoration(
                          border: _controlBorder,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                        ),
                        items: IvComparison.values
                            .map(
                              (value) => DropdownMenuItem<IvComparison>(
                                value: value,
                                child: Text(value.symbol),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onComparisonChanged(index, value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: controllers[index],
                        decoration: const InputDecoration(
                          hintText: '-1',
                          border: _controlBorder,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: index == controllers.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HoverSurface extends StatefulWidget {
  const _HoverSurface({required this.child});

  final Widget child;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xfffbfdfe) : Colors.white,
          border: Border.all(
            color: _hovered ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(_controlRadius),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _ResultContextMenu extends StatelessWidget {
  const _ResultContextMenu({
    required this.enabled,
    required this.onSendToCalibration,
    required this.onSaveTarget,
    required this.child,
  });

  final bool enabled;
  final VoidCallback? onSendToCalibration;
  final VoidCallback? onSaveTarget;
  final Widget child;

  Future<void> _show(BuildContext context, Offset position) async {
    if (!enabled || (onSendToCalibration == null && onSaveTarget == null)) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final l10n = AppLocalizations.of(context)!;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (onSendToCalibration != null)
          PopupMenuItem<String>(
            value: 'calibrate',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gps_fixed, size: 18),
                const SizedBox(width: 8),
                Text(l10n.sendToCalibration),
              ],
            ),
          ),
        if (onSaveTarget != null)
          PopupMenuItem<String>(
            value: 'save',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bookmark_add, size: 18),
                const SizedBox(width: 8),
                Text(l10n.saveTarget),
              ],
            ),
          ),
      ],
    );
    if (selected == 'calibrate') {
      onSendToCalibration?.call();
    } else if (selected == 'save') {
      onSaveTarget?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => _show(context, details.globalPosition),
      onLongPressStart: (details) => _show(context, details.globalPosition),
      child: child,
    );
  }
}

class _WildResultTile extends StatelessWidget {
  const _WildResultTile({
    required this.state,
    required this.triggerAdvance,
    required this.natureName,
    required this.personalData,
  });

  final WildState state;
  final int triggerAdvance;
  final String natureName;
  final Gen3PersonalData? personalData;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hiddenPower = state.ivs.hiddenPower;
    final stats = _resultStats(
      personalData: personalData,
      species: state.species,
      ivs: state.ivs,
      nature: state.nature,
      level: state.level,
    );
    return _HoverSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ResultField(
                    label: l10n.resultAdvance,
                    value: '${state.advance}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.resultPress,
                    value: '$triggerAdvance',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.slot,
                    value: '${state.encounterSlot}',
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ValueIconField(
                    label: l10n.levelShort,
                    value: '${state.level}',
                    showIcon: state.shiny,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.gender,
                    value: _genderLabel(state.gender),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(label: l10n.nature, value: natureName),
                ),
              ],
            ),
            _HiddenPowerIvsRow(
              hiddenPowerLabel: l10n.hiddenPower,
              hiddenPowerValue:
                  '${_hiddenPowerTypeLabel(context, hiddenPower.type)} ${hiddenPower.power}',
              ivsValue: state.ivs.toString(),
            ),
            _PidStatsRow(
              pidValue: state.pid.toString(),
              statsValue: stats?.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticResultTile extends StatelessWidget {
  const _StaticResultTile({
    required this.hit,
    required this.triggerAdvance,
    required this.natureName,
    required this.personalData,
  });

  final StaticSearchHit hit;
  final int triggerAdvance;
  final String natureName;
  final Gen3PersonalData? personalData;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = hit.state;
    final hiddenPower = state.ivs.hiddenPower;
    final stats = _resultStats(
      personalData: personalData,
      species: hit.template.species,
      ivs: state.ivs,
      nature: state.nature,
      level: state.level,
    );
    return _HoverSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ResultField(
                    label: l10n.resultAdvance,
                    value: '${state.advance}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.resultPress,
                    value: '$triggerAdvance',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.encounter,
                    value: _staticEncounterTypeLabel(
                      context,
                      hit.template.type,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ValueIconField(
                    label: l10n.levelShort,
                    value: '${state.level}',
                    showIcon: state.shiny,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.gender,
                    value: _genderLabel(state.gender),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(label: l10n.nature, value: natureName),
                ),
              ],
            ),
            _HiddenPowerIvsRow(
              hiddenPowerLabel: l10n.hiddenPower,
              hiddenPowerValue:
                  '${_hiddenPowerTypeLabel(context, hiddenPower.type)} ${hiddenPower.power}',
              ivsValue: state.ivs.toString(),
            ),
            _PidStatsRow(
              pidValue: state.pid.toString(),
              statsValue: stats?.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueIconField extends StatelessWidget {
  const _ValueIconField({
    required this.label,
    required this.value,
    required this.showIcon,
  });

  final String label;
  final String value;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (showIcon) const _ShinyIcon(),
          ],
        ),
      ],
    );
  }
}

class _ShinyIcon extends StatelessWidget {
  const _ShinyIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Tooltip(
        message: AppLocalizations.of(context)!.shiny,
        child: Icon(
          Icons.auto_awesome,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

PokemonStats? _resultStats({
  required Gen3PersonalData? personalData,
  required int species,
  required Ivs ivs,
  required Nature nature,
  required int level,
}) {
  final personalInfo = personalData?[species];
  if (personalInfo == null) {
    return null;
  }
  return calculateGen3Stats(
    personalInfo: personalInfo,
    ivs: ivs,
    nature: nature,
    level: level,
  );
}

class _PidStatsRow extends StatelessWidget {
  const _PidStatsRow({required this.pidValue, required this.statsValue});

  final String pidValue;
  final String? statsValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ResultField(label: 'PID', value: pidValue),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _ResultField(
                  label: l10n.stats,
                  value: statsValue ?? '-',
                ),
              ),
            ],
          );
        }
        final firstColumnWidth = ((constraints.maxWidth - 16) / 3)
            .clamp(0.0, constraints.maxWidth)
            .toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: firstColumnWidth,
              child: _ResultField(label: 'PID', value: pidValue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ResultField(label: l10n.stats, value: statsValue ?? '-'),
            ),
          ],
        );
      },
    );
  }
}

class _HiddenPowerIvsRow extends StatelessWidget {
  const _HiddenPowerIvsRow({
    required this.hiddenPowerLabel,
    required this.hiddenPowerValue,
    required this.ivsValue,
  });

  final String hiddenPowerLabel;
  final String hiddenPowerValue;
  final String ivsValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ResultField(
                  label: hiddenPowerLabel,
                  value: hiddenPowerValue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _ResultField(label: 'IVs', value: ivsValue),
              ),
            ],
          );
        }
        final firstColumnWidth = ((constraints.maxWidth - 16) / 3)
            .clamp(0.0, constraints.maxWidth)
            .toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: firstColumnWidth,
              child: _ResultField(
                label: hiddenPowerLabel,
                value: hiddenPowerValue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ResultField(label: 'IVs', value: ivsValue),
            ),
          ],
        );
      },
    );
  }
}

class _CalibratePage extends StatefulWidget {
  const _CalibratePage({
    required this.profile,
    required this.search,
    required this.target,
    required this.active,
  });

  final AppProfile profile;
  final _HuntSearchSnapshot? search;
  final _CalibrationPageTarget? target;
  final bool active;

  @override
  State<_CalibratePage> createState() => _CalibratePageState();
}

class _CalibratePageState extends State<_CalibratePage>
    with WidgetsBindingObserver {
  final _targetAdvanceController = TextEditingController();
  final _actualAdvanceController = TextEditingController();
  final _outputController = TextEditingController();
  final _targetDeltaController = TextEditingController();
  final _statControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  final _observedLevelController = TextEditingController();
  Future<_CalibrationNamePair>? _calibrationNamePairFuture;
  String? _calibrationNamePairLocaleName;
  int? _observedSpeciesId;
  Nature? _observedNature;
  int? _observedAbilitySlot;
  PokemonGender? _observedGender;
  List<_CalibrationHitResult> _hits = const [];
  String? _error;
  _RetailTimerConsole _timerConsole = _RetailTimerConsole.gba;
  _RetailTimerPhase _timerPhase = _RetailTimerPhase.idle;
  final _timerStopwatch = Stopwatch();
  Timer? _retailTimer;
  Timer? _timerCueTimer;
  Duration _timerPhaseDuration = Duration.zero;
  Duration _timerRemaining = Duration.zero;
  Duration _timerTargetDuration = Duration.zero;
  int? _timerTargetAdvance;
  int _timerSignalVersion = 0;
  bool _timerPhaseTransitionPending = false;
  Future<void>? _timerBeepPreparation;
  bool _timerBeepReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTarget(widget.target);
    _syncScreenAwake();
  }

  @override
  void didUpdateWidget(covariant _CalibratePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _cancelRetailTimer();
      _resetRetailTimerState();
      _syncTarget(widget.target);
    }
    if (oldWidget.active != widget.active) {
      _syncScreenAwake();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setScreenAwake(false);
    _cancelRetailTimer();
    _targetAdvanceController.dispose();
    _actualAdvanceController.dispose();
    _outputController.dispose();
    _targetDeltaController.dispose();
    _observedLevelController.dispose();
    for (final controller in _statControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _syncScreenAwake();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setScreenAwake(false);
        _stopRetailTimer();
    }
  }

  void _syncScreenAwake() {
    _setScreenAwake(widget.active);
  }

  void _setScreenAwake(bool enabled) {
    if (kIsWeb) {
      return;
    }
    unawaited(
      _screenAwakeChannel
          .invokeMethod<void>('setEnabled', {'enabled': enabled})
          .catchError((Object _) {}),
    );
  }

  void _syncTarget(_CalibrationPageTarget? target) {
    if (target == null) {
      return;
    }
    _targetAdvanceController.text = '${target.advance - target.delay}';
    _actualAdvanceController.clear();
    _outputController.clear();
    _targetDeltaController.clear();
    _observedLevelController.clear();
    _observedSpeciesId = target.species;
    _observedNature = null;
    _observedAbilitySlot = null;
    _observedGender = null;
    _hits = const [];
    _error = null;
  }

  Future<_CalibrationNamePair> _calibrationNamePair(String localeName) {
    final cached = _calibrationNamePairFuture;
    if (cached != null && _calibrationNamePairLocaleName == localeName) {
      return cached;
    }
    _calibrationNamePairLocaleName = localeName;
    return _calibrationNamePairFuture = _loadCalibrationNamePair(localeName);
  }

  Future<_CalibrationNamePair> _loadCalibrationNamePair(
    String localeName,
  ) async {
    final primaryLocale = _assetLocaleForDisplayLocale(localeName);
    final secondaryLocale = switch (primaryLocale) {
      'zh_Hans' => 'ja',
      'ja' => 'en',
      _ => 'ja',
    };
    final values = await Future.wait([
      Gen3NamedResources.loadAssetLocale(primaryLocale),
      Gen3NamedResources.loadAssetLocale(secondaryLocale),
    ]);
    return _CalibrationNamePair(primary: values[0], secondary: values[1]);
  }

  void _calculateNextPress() {
    final currentPress = int.tryParse(_targetAdvanceController.text.trim());
    final actualAdvance = int.tryParse(_actualAdvanceController.text.trim());
    if (currentPress == null || actualAdvance == null) {
      setState(() {
        _error = AppLocalizations.of(context)!.calibrationFrameInputError;
      });
      return;
    }

    final referenceAdvance = widget.target?.advance ?? currentPress;
    final delta = actualAdvance - referenceAdvance;
    final nextPress = currentPress - delta;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _error = null;
      _targetAdvanceController.text = '$nextPress';
      _actualAdvanceController.clear();
      _outputController.text = l10n.nextTargetAdvanceOutput(nextPress, delta);
      _targetDeltaController.text = l10n.targetDeltaOutput(
        nextPress - referenceAdvance,
      );
      _refreshRetailTimerPreview();
    });
  }

  bool get _retailTimerRunning {
    return _timerPhase == _RetailTimerPhase.preparation ||
        _timerPhase == _RetailTimerPhase.target;
  }

  void _refreshRetailTimerPreview() {
    if (_retailTimerRunning) {
      return;
    }
    final targetAdvance = int.tryParse(_targetAdvanceController.text.trim());
    if (targetAdvance == null || targetAdvance < 0) {
      _timerTargetAdvance = null;
      _timerTargetDuration = Duration.zero;
      return;
    }
    _timerTargetAdvance = targetAdvance;
    _timerTargetDuration = _timerDurationForAdvance(targetAdvance);
  }

  void _toggleRetailTimer() {
    if (_retailTimerRunning) {
      _stopRetailTimer();
      return;
    }
    _startRetailTimer();
  }

  void _startRetailTimer() {
    final targetAdvance = int.tryParse(_targetAdvanceController.text.trim());
    if (targetAdvance == null || targetAdvance < 0) {
      setState(() {
        _error = AppLocalizations.of(context)!.timerInputError;
      });
      return;
    }

    _prepareTimerBeep();
    _retailTimer?.cancel();
    _timerCueTimer?.cancel();
    _timerSignalVersion++;
    _timerStopwatch
      ..reset()
      ..start();
    setState(() {
      _error = null;
      _timerTargetAdvance = targetAdvance;
      _timerTargetDuration = _timerDurationForAdvance(targetAdvance);
      _timerPhase = _RetailTimerPhase.preparation;
      _timerPhaseDuration = _retailTimerPreparation;
      _timerRemaining = _retailTimerPreparation;
      _timerPhaseTransitionPending = false;
    });
    _scheduleTimerCue(_RetailTimerPhase.preparation, _retailTimerPreparation);
    _retailTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickRetailTimer(),
    );
  }

  void _stopRetailTimer() {
    _cancelRetailTimer();
    if (!mounted) {
      return;
    }
    setState(() {
      _resetRetailTimerState();
    });
  }

  void _cancelRetailTimer() {
    _timerSignalVersion++;
    _timerCueTimer?.cancel();
    _timerCueTimer = null;
    _retailTimer?.cancel();
    _retailTimer = null;
    _timerStopwatch
      ..stop()
      ..reset();
    _timerPhaseTransitionPending = false;
  }

  void _resetRetailTimerState() {
    _timerPhase = _RetailTimerPhase.idle;
    _timerPhaseDuration = Duration.zero;
    _timerRemaining = Duration.zero;
    _timerTargetAdvance = null;
    _timerPhaseTransitionPending = false;
  }

  void _tickRetailTimer() {
    if (!mounted) {
      _cancelRetailTimer();
      return;
    }

    if (_timerPhaseTransitionPending) {
      return;
    }

    final remaining = _timerPhaseDuration - _timerStopwatch.elapsed;
    if (remaining > Duration.zero) {
      setState(() => _timerRemaining = remaining);
      return;
    }

    if (_timerPhase == _RetailTimerPhase.preparation) {
      setState(() {
        _timerRemaining = Duration.zero;
        _timerPhaseTransitionPending = true;
      });
      _signalRetailTimerAfterFrame(() {
        if (_timerPhase != _RetailTimerPhase.preparation ||
            !_timerPhaseTransitionPending) {
          return;
        }
        _timerStopwatch
          ..reset()
          ..start();
        setState(() {
          _timerPhase = _RetailTimerPhase.target;
          _timerPhaseDuration = _timerTargetDuration;
          _timerRemaining = _timerTargetDuration;
          _timerPhaseTransitionPending = false;
        });
        _scheduleTimerCue(_RetailTimerPhase.target, _timerTargetDuration);
      });
      return;
    }

    _cancelRetailTimer();
    setState(() {
      _timerPhase = _RetailTimerPhase.finished;
      _timerRemaining = Duration.zero;
    });
    _signalRetailTimerAfterFrame();
  }

  void _signalRetailTimerAfterFrame([VoidCallback? afterSignal]) {
    final signalVersion = _timerSignalVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || signalVersion != _timerSignalVersion) {
        return;
      }
      _signalRetailTimer();
      afterSignal?.call();
    });
  }

  void _signalRetailTimer() {
    unawaited(_playTimerHaptics());
  }

  void _scheduleTimerCue(_RetailTimerPhase phase, Duration phaseDuration) {
    _timerCueTimer?.cancel();
    final cueDelay = phaseDuration - _retailTimerCueLead;
    final signalVersion = _timerSignalVersion;
    _timerCueTimer = Timer(
      cueDelay <= Duration.zero ? Duration.zero : cueDelay,
      () {
        if (!mounted ||
            signalVersion != _timerSignalVersion ||
            _timerPhase != phase) {
          return;
        }
        unawaited(_playTimerBeep());
      },
    );
  }

  void _prepareTimerBeep() {
    if (kIsWeb) {
      return;
    }
    final preparation = _timerBeepPreparation;
    if (preparation != null) {
      return;
    }
    _timerBeepPreparation = _timerBeepChannel
        .invokeMethod<void>('prepare')
        .then<void>((_) {
          _timerBeepReady = true;
        })
        .catchError((Object _) {
          _timerBeepReady = false;
          _timerBeepPreparation = null;
        });
  }

  Future<void> _playTimerBeep() async {
    if (kIsWeb) {
      unawaited(SystemSound.play(_timerSoundType));
      return;
    }
    try {
      if (!_timerBeepReady) {
        _prepareTimerBeep();
        await _timerBeepPreparation;
      }
      await _timerBeepChannel.invokeMethod<void>('play');
    } catch (_) {
      unawaited(SystemSound.play(_timerSoundType));
    }
  }

  SystemSoundType get _timerSoundType {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => SystemSoundType.click,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => SystemSoundType.alert,
    };
  }

  Future<void> _playTimerHaptics() async {
    if (kIsWeb) {
      return;
    }
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  Duration _timerDurationForAdvance(int advance) {
    final milliseconds = advance * 1000 / _timerFrameRate;
    return Duration(microseconds: (milliseconds * 1000).round());
  }

  double get _timerFrameRate {
    return switch (_timerConsole) {
      _RetailTimerConsole.gba => _gbaFrameRate,
      _RetailTimerConsole.ndsSlot2 => _ndsSlot2FrameRate,
      _RetailTimerConsole.ndsFamily => _ndsFamilyFrameRate,
    };
  }

  void _reverseHit() {
    final observedStats = _parseStats();
    final observedLevel = _parseObservedLevel();
    final observedNature = _observedNature;
    final target = widget.target;

    if ((target == null && widget.search == null) ||
        observedStats == null ||
        observedLevel == null ||
        observedNature == null) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.runHuntAndEnterObservedStatsError;
        _hits = const [];
      });
      return;
    }

    final hits = switch (target) {
      _CalibrationTarget() => _findWildHits(
        target,
        observedStats,
        observedLevel,
        observedNature,
      ),
      _StaticTarget() => _findStaticHits(
        target,
        observedStats,
        observedLevel,
        observedNature,
      ),
      null => _findWildHitsFromSearch(
        widget.search!,
        observedStats,
        observedLevel,
        observedNature,
      ),
    };

    if (hits.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context)!.noMatchingAdvanceError;
        _hits = const [];
      });
      return;
    }

    setState(() {
      _error = null;
      _hits = hits;
    });
  }

  List<_CalibrationHitResult> _findWildHits(
    _CalibrationTarget target,
    PokemonStats observedStats,
    int observedLevel,
    Nature observedNature,
  ) {
    return _findWildHitsFromSearch(
      target.search,
      observedStats,
      observedLevel,
      observedNature,
      defaultSpeciesId: target.species,
    );
  }

  List<_CalibrationHitResult> _findWildHitsFromSearch(
    _HuntSearchSnapshot search,
    PokemonStats observedStats,
    int observedLevel,
    Nature observedNature, {
    int? defaultSpeciesId,
  }) {
    final observedSpeciesId =
        _observedSpeciesId ?? defaultSpeciesId ?? search.speciesId;
    final hits = <_CalibrationHitResult>[];
    for (final method in _wildReverseMethods(search.method)) {
      final request = WildCalibrationRequest(
        seed: search.seed,
        initialAdvance: search.initialAdvance,
        maxAdvance: search.maxAdvance,
        delay: search.delay,
        method: method,
        area: search.area,
        tid: widget.profile.tid,
        sid: widget.profile.sid,
        speciesId: observedSpeciesId,
        observedLevel: observedLevel,
        observedStats: observedStats,
        observedNature: observedNature,
        abilitySlot: _observedAbilitySlot,
        gender: _observedGender,
        synchronizeNature: search.synchronizeNature,
        pressureLead: search.pressureLead,
        staticLead: search.staticLead,
        magnetPullLead: search.magnetPullLead,
        cuteCharmLead: search.cuteCharmLead,
        feebasTile: search.feebasTile,
        personalData: search.personalData,
      );
      hits.addAll(
        request.findMatches(limit: 50).map(_CalibrationHitResult.wild),
      );
    }
    hits.sort((left, right) {
      final advanceCompare = left.advance.compareTo(right.advance);
      if (advanceCompare != 0) {
        return advanceCompare;
      }
      return (left.wildMethod?.index ?? 0).compareTo(
        right.wildMethod?.index ?? 0,
      );
    });
    return hits.take(50).toList(growable: false);
  }

  List<_CalibrationHitResult> _findStaticHits(
    _StaticTarget target,
    PokemonStats observedStats,
    int observedLevel,
    Nature observedNature,
  ) {
    final search = target.search;
    final template = search.template;
    final personalInfo = search.personalData[template.species];
    if (personalInfo == null) {
      return const [];
    }
    final generator = StaticGenerator(
      seed: search.seed,
      initialAdvance: search.initialAdvance,
      maxAdvances: search.maxAdvance,
      method: search.method,
      tid: widget.profile.tid,
      sid: widget.profile.sid,
      genderRatio: personalInfo.genderRatio,
      level: template.level,
      buggedRoamer: template.buggedRoamer,
    );
    final results = <_CalibrationHitResult>[];
    for (final state in generator.generate()) {
      if (state.level != observedLevel) {
        continue;
      }
      if (state.nature != observedNature) {
        continue;
      }
      if (_observedAbilitySlot != null &&
          state.abilitySlot != _observedAbilitySlot) {
        continue;
      }
      if (_observedGender != null && state.gender != _observedGender) {
        continue;
      }
      final stats = calculateGen3Stats(
        personalInfo: personalInfo,
        ivs: state.ivs,
        nature: state.nature,
        level: state.level,
      );
      if (!_sameStats(stats, observedStats)) {
        continue;
      }
      results.add(_CalibrationHitResult.static(state, template, stats));
      if (results.length >= 50) {
        break;
      }
    }
    return results;
  }

  bool _sameStats(PokemonStats left, PokemonStats right) {
    final leftValues = left.ordered;
    final rightValues = right.ordered;
    for (var index = 0; index < leftValues.length; index += 1) {
      if (leftValues[index] != rightValues[index]) {
        return false;
      }
    }
    return true;
  }

  int? _parseObservedLevel() {
    final level = int.tryParse(_observedLevelController.text.trim());
    if (level == null || level < 1 || level > 100) {
      return null;
    }
    return level;
  }

  PokemonStats? _parseStats() {
    final values = _statControllers
        .map((controller) => int.tryParse(controller.text.trim()))
        .toList();
    if (values.any((value) => value == null || value < 1)) {
      return null;
    }
    final stats = values.cast<int>();
    return PokemonStats(
      hp: stats[0],
      attack: stats[1],
      defense: stats[2],
      specialAttack: stats[3],
      specialDefense: stats[4],
      speed: stats[5],
    );
  }

  List<DropdownMenuItem<int?>> _abilityItems(
    BuildContext context,
    Gen3PersonalInfo? personal,
    Gen3NamedResources? names, {
    Gen3NamedResources? secondaryNames,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return [
      DropdownMenuItem<int?>(value: null, child: Text(l10n.any)),
      if (personal != null)
        ...List<DropdownMenuItem<int?>>.generate(2, (slot) {
          final id = personal.abilityIds[slot];
          final name = _pairedName(
            names?.abilityName(id) ?? 'Ability $id',
            secondaryNames?.abilityName(id),
          );
          return DropdownMenuItem<int?>(
            value: slot,
            child: Text(
              _abilitySlotLabel(context: context, slot: slot, name: name),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
    ];
  }

  List<DropdownMenuItem<int>> _speciesItems(
    _HuntSearchSnapshot? search,
    Gen3NamedResources? names,
  ) {
    if (search == null) {
      return const [];
    }
    final speciesIds = <int>[];
    for (final slot in search.area.slots) {
      if (!speciesIds.contains(slot.species)) {
        speciesIds.add(slot.species);
      }
    }
    if (!speciesIds.contains(search.speciesId)) {
      speciesIds.insert(0, search.speciesId);
    }
    return speciesIds
        .map(
          (speciesId) => DropdownMenuItem<int>(
            value: speciesId,
            child: Text(
              '#$speciesId ${names?.speciesName(speciesId) ?? speciesId}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _statFields(AppLocalizations l10n) {
    final labels = [
      'HP',
      l10n.statAttack,
      l10n.statDefense,
      l10n.statSpecialAttack,
      l10n.statSpecialDefense,
      l10n.statSpeed,
    ];
    return List<Widget>.generate(labels.length, (index) {
      return SizedBox(
        width: 108,
        child: _ClearOnFirstFocusTextField(
          controller: _statControllers[index],
          decoration: InputDecoration(
            labelText: labels[index],
            border: _controlBorder,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );
    }, growable: false);
  }

  Widget _retailTimerPanel(AppLocalizations l10n, ThemeData theme) {
    final currentTarget = int.tryParse(_targetAdvanceController.text.trim());
    final displayTarget = _timerTargetAdvance ?? currentTarget;
    final displayDuration = displayTarget == null || displayTarget < 0
        ? null
        : _timerDurationForAdvance(displayTarget);
    final running = _retailTimerRunning;
    final phaseLabel = _retailTimerPhaseLabel(l10n);
    final remaining = running ? _timerRemaining : displayDuration;

    return _HoverSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.retailTimer,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(phaseLabel, style: theme.textTheme.labelMedium),
              ],
            ),
            DropdownButtonFormField<_RetailTimerConsole>(
              isExpanded: true,
              initialValue: _timerConsole,
              decoration: InputDecoration(
                labelText: l10n.timerConsole,
                border: _controlBorder,
              ),
              items: _RetailTimerConsole.values
                  .map(
                    (value) => DropdownMenuItem<_RetailTimerConsole>(
                      value: value,
                      child: Text(_retailTimerConsoleLabel(l10n, value)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: running
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _timerConsole = value);
                      }
                    },
            ),
            Row(
              children: [
                Expanded(
                  child: _ResultField(
                    label: l10n.timerPreparation,
                    value: _formatDuration(_retailTimerPreparation),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultField(
                    label: l10n.timerTargetCountdown,
                    value: remaining == null ? '-' : _formatDuration(remaining),
                  ),
                ),
              ],
            ),
            Text(
              displayTarget == null
                  ? l10n.timerTargetFrame('-')
                  : l10n.timerTargetFrame(displayTarget),
              style: theme.textTheme.labelSmall,
            ),
            Text(
              displayDuration == null
                  ? l10n.timerTargetDuration('-')
                  : l10n.timerTargetDuration(_formatDuration(displayDuration)),
              style: theme.textTheme.labelSmall,
            ),
            Text(l10n.timerPreparationNote, style: theme.textTheme.labelSmall),
            if (kIsWeb)
              Text(
                l10n.timerWebSoundUnsupported,
                style: theme.textTheme.labelSmall,
              ),
            Text(l10n.timerEmeraldOnlyNote, style: theme.textTheme.labelSmall),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleRetailTimer,
                icon: Icon(running ? Icons.stop : Icons.play_arrow),
                label: Text(running ? l10n.timerStop : l10n.timerStart),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _retailTimerPhaseLabel(AppLocalizations l10n) {
    return switch (_timerPhase) {
      _RetailTimerPhase.idle => l10n.timerReady,
      _RetailTimerPhase.preparation => l10n.timerPreparation,
      _RetailTimerPhase.target => l10n.timerTargetCountdown,
      _RetailTimerPhase.finished => l10n.timerFinished,
    };
  }

  String _retailTimerConsoleLabel(
    AppLocalizations l10n,
    _RetailTimerConsole value,
  ) {
    return switch (value) {
      _RetailTimerConsole.gba => l10n.timerConsoleGba,
      _RetailTimerConsole.ndsSlot2 => l10n.timerConsoleNdsSlot2,
      _RetailTimerConsole.ndsFamily => l10n.timerConsoleNdsFamily,
    };
  }

  void _selectHit(_CalibrationHitResult hit) {
    final l10n = AppLocalizations.of(context)!;
    _actualAdvanceController.text = '${hit.advance}';
    _outputController.text = l10n.actualAdvanceOutput(hit.advance);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.actualAdvanceUpdated),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = widget.target;
    final wildSearch = target is _CalibrationTarget
        ? target.search
        : widget.search;
    final observedSpeciesId =
        _observedSpeciesId ?? target?.species ?? wildSearch?.speciesId;
    final personalData = target?.personalData ?? wildSearch?.personalData;
    final personal = observedSpeciesId == null
        ? null
        : personalData?[observedSpeciesId];
    final names = target?.names;
    final isStaticTarget = target is _StaticTarget;
    final hitDelay = target?.delay ?? wildSearch?.delay ?? 0;
    final theme = Theme.of(context);
    final localeName = Localizations.localeOf(context).toString();

    return FutureBuilder<_CalibrationNamePair>(
      future: _calibrationNamePair(localeName),
      builder: (context, snapshot) {
        final calibrationNames = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.calibrate, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _CalibrationTargetCard(target: target),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetAdvanceController,
                    decoration: InputDecoration(
                      labelText: l10n.currentTargetAdvance,
                      border: _controlBorder,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(_refreshRetailTimerPreview);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _actualAdvanceController,
                    decoration: InputDecoration(
                      labelText: l10n.actualAdvance,
                      border: _controlBorder,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _outputController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.calibrationOutput,
                border: _controlBorder,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetDeltaController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.targetDelta,
                border: _controlBorder,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _calculateNextPress,
                icon: const Icon(Icons.calculate),
                label: Text(l10n.calculateNextPress),
              ),
            ),
            const SizedBox(height: 12),
            _retailTimerPanel(l10n, theme),
            const SizedBox(height: 20),
            if (!isStaticTarget) ...[
              Text(l10n.observedPokemon, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('calibration-species-$observedSpeciesId'),
                isExpanded: true,
                initialValue: observedSpeciesId,
                decoration: InputDecoration(
                  labelText: l10n.pokemon,
                  border: _controlBorder,
                ),
                items: _speciesItems(wildSearch, names),
                onChanged: wildSearch == null
                    ? null
                    : (value) {
                        setState(() {
                          _observedSpeciesId = value;
                          _observedAbilitySlot = null;
                          _observedGender = null;
                          _hits = const [];
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _observedLevelController,
                    decoration: InputDecoration(
                      labelText: l10n.levelShort,
                      border: _controlBorder,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'calibration-ability-$observedSpeciesId-$_observedAbilitySlot',
                    ),
                    isExpanded: true,
                    initialValue: _observedAbilitySlot,
                    decoration: InputDecoration(
                      labelText: l10n.ability,
                      border: _controlBorder,
                    ),
                    items: _abilityItems(
                      context,
                      personal,
                      calibrationNames?.primary ?? names,
                      secondaryNames: calibrationNames?.secondary,
                    ),
                    onChanged: personal == null
                        ? null
                        : (value) =>
                              setState(() => _observedAbilitySlot = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Nature>(
                    isExpanded: true,
                    initialValue: _observedNature,
                    decoration: InputDecoration(
                      labelText: l10n.nature,
                      border: _controlBorder,
                    ),
                    items: Nature.values
                        .map(
                          (nature) => DropdownMenuItem<Nature>(
                            value: nature,
                            child: Text(
                              _calibrationNatureLabel(
                                nature,
                                primaryNames:
                                    calibrationNames?.primary ?? names,
                                secondaryNames: calibrationNames?.secondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => _observedNature = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<PokemonGender?>(
                    key: ValueKey(
                      'calibration-gender-$observedSpeciesId-$_observedGender',
                    ),
                    isExpanded: true,
                    initialValue: _observedGender,
                    decoration: InputDecoration(
                      labelText: l10n.gender,
                      border: _controlBorder,
                    ),
                    items: [
                      DropdownMenuItem<PokemonGender?>(
                        value: null,
                        child: Text(l10n.any),
                      ),
                      ..._legalGenders(personal).map(
                        (gender) => DropdownMenuItem<PokemonGender?>(
                          value: gender,
                          child: Text(_genderLabel(gender)),
                        ),
                      ),
                    ],
                    onChanged: personal == null
                        ? null
                        : (value) => setState(() => _observedGender = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.observedStats, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _statFields(l10n)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _reverseHit,
                icon: const Icon(Icons.manage_search),
                label: Text(l10n.reverseHitAdvance),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_hits.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.reverseResults, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._hits.map(
                (hit) => _CalibrationHitTile(
                  hit: hit,
                  triggerAdvance: hit.advance - hitDelay,
                  speciesName:
                      names?.speciesName(hit.species) ?? '#${hit.species}',
                  natureName: names?.natureName(hit.nature) ?? hit.nature.name,
                  onTap: () => _selectHit(hit),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CalibrationNamePair {
  const _CalibrationNamePair({required this.primary, required this.secondary});

  final Gen3NamedResources primary;
  final Gen3NamedResources secondary;
}

class _CalibrationTargetCard extends StatelessWidget {
  const _CalibrationTargetCard({required this.target});

  final _CalibrationPageTarget? target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = this.target;
    if (target == null) {
      return _HoverSurface(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l10n.noCalibrationTarget),
        ),
      );
    }

    final species = target.names.speciesName(target.species);
    return _HoverSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.calibrationTarget,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '#${target.species} $species · '
                          '${target.kindLabel(context)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (target.shiny) const _ShinyIcon(),
                    ],
                  ),
                ),
                Text('${l10n.resultAdvance} ${target.advance}'),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.levelShort} ${target.level} · '
                    '${_genderLabel(target.gender)} · '
                    '${target.names.natureName(target.nature)}',
                  ),
                ),
                Text('PID ${target.pid}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationHitResult {
  const _CalibrationHitResult({
    required this.advance,
    required this.species,
    required this.level,
    required this.nature,
    required this.gender,
    required this.ivs,
    required this.stats,
    this.wildMethod,
  });

  factory _CalibrationHitResult.wild(WildCalibrationHit hit) {
    final state = hit.state;
    return _CalibrationHitResult(
      advance: state.advance,
      species: state.species,
      level: state.level,
      nature: state.nature,
      gender: state.gender,
      ivs: state.ivs,
      stats: hit.stats,
      wildMethod: hit.method,
    );
  }

  factory _CalibrationHitResult.static(
    StaticState state,
    StaticEncounterTemplate template,
    PokemonStats stats,
  ) {
    return _CalibrationHitResult(
      advance: state.advance,
      species: template.species,
      level: state.level,
      nature: state.nature,
      gender: state.gender,
      ivs: state.ivs,
      stats: stats,
    );
  }

  final int advance;
  final int species;
  final int level;
  final Nature nature;
  final PokemonGender gender;
  final Ivs ivs;
  final PokemonStats? stats;
  final WildMethod? wildMethod;
}

class _CalibrationHitTile extends StatelessWidget {
  const _CalibrationHitTile({
    required this.hit,
    required this.triggerAdvance,
    required this.speciesName,
    required this.natureName,
    required this.onTap,
  });

  final _CalibrationHitResult hit;
  final int triggerAdvance;
  final String speciesName;
  final String natureName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = hit.stats;
    final methodText = hit.wildMethod == null
        ? ''
        : '${_wildMethodLabel(context, hit.wildMethod!)} · ';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _HoverSurface(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_controlRadius),
            onTap: onTap,
            child: ListTile(
              dense: true,
              title: Text(
                '#${hit.species} $speciesName · '
                '${l10n.resultAdvance} ${hit.advance} · '
                '${l10n.resultPress} $triggerAdvance · '
                '$methodText'
                '${l10n.levelShort} ${hit.level}',
              ),
              subtitle: Text(
                '$natureName · ${_genderLabel(hit.gender)} · '
                '${stats ?? hit.ivs}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreedingPage extends StatefulWidget {
  const _BreedingPage({required this.profile, required this.storage});

  final AppProfile profile;
  final _AppStorage storage;

  @override
  State<_BreedingPage> createState() => _BreedingPageState();
}

class _BreedingPageState extends State<_BreedingPage> {
  final _pokemonController = TextEditingController();
  final _pokemonFocusNode = FocusNode();
  final _heldSeedController = TextEditingController(text: '00000000');
  final _pickupSeedController = TextEditingController(text: '00000000');
  final _heldInitialController = TextEditingController(text: '1000');
  final _heldMaxController = TextEditingController(text: '5000');
  final _heldOffsetController = TextEditingController(text: '0');
  final _pickupInitialController = TextEditingController(text: '1000');
  final _pickupMaxController = TextEditingController(text: '5000');
  final _pickupOffsetController = TextEditingController(text: '0');
  final _calibrationController = TextEditingController(text: '18');
  final _minRedrawController = TextEditingController(text: '0');
  final _maxRedrawController = TextEditingController(text: '5');
  final _ivControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(text: '-1'),
  );
  final _parentIvControllers = List<List<TextEditingController>>.generate(
    2,
    (_) => List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(text: '31'),
    ),
  );
  final _ivComparisons = List<IvComparison>.filled(
    6,
    IvComparison.greaterOrEqual,
  );

  int? _speciesId;
  EggMethod3 _method = EggMethod3.emeraldBred;
  int _compatibility = 70;
  bool _shinyOnly = false;
  Nature? _nature;
  HiddenPowerType? _hiddenPowerType;
  int? _abilitySlot;
  PokemonGender? _gender;
  final _parentGenders = <DaycareParentGender>[
    DaycareParentGender.male,
    DaycareParentGender.female,
  ];
  final _parentNatures = <Nature>[Nature.hardy, Nature.hardy];
  final _parentItems = <int>[0, 0];
  EggSearchResult? _result;
  String? _error;
  bool _searching = false;
  bool _settingsLoaded = false;
  bool _suppressSettingsSave = false;
  Timer? _settingsSaveTimer;

  @override
  void initState() {
    super.initState();
    _method = _defaultEggMethod(widget.profile.game);
    _addSettingsListeners();
    _loadEggSettings(widget.profile.game);
  }

  @override
  void didUpdateWidget(covariant _BreedingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.game != widget.profile.game) {
      final methods = _eggMethodsForGame(widget.profile.game);
      _settingsLoaded = false;
      _applyEggSettings(_EggSettingsRecord.defaultsFor(widget.profile.game));
      _result = null;
      _error = null;
      if (!methods.contains(_method)) {
        _method = methods.first;
      }
      _loadEggSettings(widget.profile.game);
    }
  }

  @override
  void dispose() {
    _saveEggSettingsNow();
    _settingsSaveTimer?.cancel();
    _pokemonController.dispose();
    _pokemonFocusNode.dispose();
    _heldSeedController.dispose();
    _pickupSeedController.dispose();
    _heldInitialController.dispose();
    _heldMaxController.dispose();
    _heldOffsetController.dispose();
    _pickupInitialController.dispose();
    _pickupMaxController.dispose();
    _pickupOffsetController.dispose();
    _calibrationController.dispose();
    _minRedrawController.dispose();
    _maxRedrawController.dispose();
    for (final controller in _ivControllers) {
      controller.dispose();
    }
    for (final parent in _parentIvControllers) {
      for (final controller in parent) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _addSettingsListeners() {
    final controllers = <TextEditingController>[
      _pokemonController,
      _heldSeedController,
      _pickupSeedController,
      _heldInitialController,
      _heldMaxController,
      _heldOffsetController,
      _pickupInitialController,
      _pickupMaxController,
      _pickupOffsetController,
      _calibrationController,
      _minRedrawController,
      _maxRedrawController,
      ..._ivControllers,
      for (final parent in _parentIvControllers) ...parent,
    ];
    for (final controller in controllers) {
      controller.addListener(_scheduleSaveEggSettings);
    }
  }

  Future<void> _loadEggSettings(GameVersion game) async {
    final settings = await widget.storage.loadEggSettings(game);
    if (!mounted || widget.profile.game != game) {
      return;
    }
    setState(() {
      _applyEggSettings(settings);
      _settingsLoaded = true;
    });
  }

  void _applyEggSettings(_EggSettingsRecord settings) {
    _suppressSettingsSave = true;
    _speciesId = settings.speciesId;
    _pokemonController.clear();
    final methods = _eggMethodsForGame(widget.profile.game);
    _method = methods.contains(settings.method)
        ? settings.method
        : methods.first;
    _compatibility = settings.compatibility;
    _shinyOnly = settings.shinyOnly;
    _nature = settings.nature;
    _hiddenPowerType = settings.hiddenPowerType;
    _abilitySlot = settings.abilitySlot;
    _gender = settings.gender;
    _heldSeedController.text = settings.heldSeed;
    _pickupSeedController.text = settings.pickupSeed;
    _heldInitialController.text = settings.heldInitial;
    _heldMaxController.text = settings.heldMax;
    _heldOffsetController.text = settings.heldOffset;
    _pickupInitialController.text = settings.pickupInitial;
    _pickupMaxController.text = settings.pickupMax;
    _pickupOffsetController.text = settings.pickupOffset;
    _calibrationController.text = settings.calibration;
    _minRedrawController.text = settings.minRedraws;
    _maxRedrawController.text = settings.maxRedraws;
    for (var i = 0; i < 6; i += 1) {
      _ivControllers[i].text = '${settings.ivRules[i].value}';
      _ivComparisons[i] = settings.ivRules[i].comparison;
    }
    for (var parent = 0; parent < 2; parent += 1) {
      _parentGenders[parent] = settings.parentGenders[parent];
      _parentNatures[parent] = settings.parentNatures[parent];
      _parentItems[parent] = settings.parentItems[parent];
      final ivs = settings.parentIvs[parent].ordered;
      for (var stat = 0; stat < 6; stat += 1) {
        _parentIvControllers[parent][stat].text = '${ivs[stat]}';
      }
    }
    _suppressSettingsSave = false;
  }

  void _scheduleSaveEggSettings() {
    if (!_settingsLoaded || _suppressSettingsSave) {
      return;
    }
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = Timer(
      const Duration(milliseconds: 350),
      _saveEggSettingsNow,
    );
  }

  void _saveEggSettingsNow() {
    if (!_settingsLoaded || _suppressSettingsSave) {
      return;
    }
    unawaited(
      widget.storage.saveEggSettings(
        widget.profile.game,
        _EggSettingsRecord.fromPage(this),
      ),
    );
  }

  void _updateEggSettings(VoidCallback update) {
    setState(update);
    _scheduleSaveEggSettings();
  }

  void _resetEggSettingsToDefaults() {
    setState(() {
      _applyEggSettings(_EggSettingsRecord.defaultsFor(widget.profile.game));
      _settingsLoaded = true;
      _result = null;
      _error = null;
    });
    _saveEggSettingsNow();
  }

  Future<void> _search(_HuntData data) async {
    final request = _buildRequest(data);
    if (request == null) {
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _result = null;
    });
    try {
      final result = kIsWeb
          ? request.search()
          : await Isolate.run(request.search);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _searching = false;
      });
    }
  }

  EggSearchRequest? _buildRequest(_HuntData data) {
    final heldSeed = _parseHexInput(_heldSeedController.text);
    final pickupSeed = _parseHexInput(_pickupSeedController.text);
    final heldInitial = int.tryParse(_heldInitialController.text.trim());
    final heldMax = int.tryParse(_heldMaxController.text.trim());
    final heldOffset = int.tryParse(_heldOffsetController.text.trim());
    final pickupInitial = int.tryParse(_pickupInitialController.text.trim());
    final pickupMax = int.tryParse(_pickupMaxController.text.trim());
    final pickupOffset = int.tryParse(_pickupOffsetController.text.trim());
    final calibration = int.tryParse(_calibrationController.text.trim());
    final minRedraw = int.tryParse(_minRedrawController.text.trim());
    final maxRedraw = int.tryParse(_maxRedrawController.text.trim());
    final ivFilter = _parseEggIvFilter();
    final parentIvs = _parseParentIvs();
    if (_speciesId == null ||
        heldSeed == null ||
        pickupSeed == null ||
        heldInitial == null ||
        heldMax == null ||
        heldOffset == null ||
        pickupInitial == null ||
        pickupMax == null ||
        pickupOffset == null ||
        calibration == null ||
        minRedraw == null ||
        maxRedraw == null ||
        ivFilter == null ||
        parentIvs == null ||
        heldInitial < 0 ||
        pickupInitial < 0 ||
        heldMax < heldInitial ||
        pickupMax < pickupInitial ||
        heldMax - heldInitial > _maxEggAdvanceDelta ||
        pickupMax - pickupInitial > _maxEggAdvanceDelta ||
        minRedraw < 0 ||
        maxRedraw < minRedraw) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.eggInputError(_maxEggAdvanceDelta);
      });
      return null;
    }

    return EggSearchRequest(
      initialAdvances: heldInitial,
      maxAdvances: heldMax - heldInitial,
      offset: heldOffset,
      initialPickupAdvances: pickupInitial,
      maxPickupAdvances: pickupMax - pickupInitial,
      pickupOffset: pickupOffset,
      calibration: calibration,
      minRedraws: minRedraw,
      maxRedraws: maxRedraw,
      method: _method,
      compatibility: _compatibility,
      daycare: Daycare3(
        parentA: _parent(0, parentIvs[0]),
        parentB: _parent(1, parentIvs[1]),
        eggSpecies: _speciesId!,
      ),
      personalData: data.personal,
      tid: widget.profile.tid,
      sid: widget.profile.sid,
      ivFilter: ivFilter,
      heldSeed: heldSeed,
      pickupSeed: pickupSeed,
      resultLimit: _maxDisplayedResults,
      shinyOnly: _shinyOnly,
      speciesId: _speciesId,
      nature: _nature,
      hiddenPowerType: _hiddenPowerType,
      abilitySlot: _abilitySlot,
      gender: _gender,
    );
  }

  DaycareParent3 _parent(int index, Ivs ivs) {
    return DaycareParent3(
      ivs: ivs,
      gender: _parentGenders[index],
      nature: _parentNatures[index],
      item: _parentItems[index],
    );
  }

  IvFilter? _parseEggIvFilter() {
    final values = _ivControllers
        .map((controller) => int.tryParse(controller.text.trim()))
        .toList();
    if (values.any((value) => value == null || value < -1 || value > 31)) {
      return null;
    }
    return IvFilter(
      rules: [
        for (var i = 0; i < values.length; i += 1)
          IvRule(value: values[i]!, comparison: _ivComparisons[i]),
      ],
    );
  }

  List<Ivs>? _parseParentIvs() {
    final result = <Ivs>[];
    for (final parent in _parentIvControllers) {
      final values = parent
          .map((controller) => int.tryParse(controller.text.trim()))
          .toList();
      if (values.any((value) => value == null || value < 0 || value > 31)) {
        return null;
      }
      final ivs = values.cast<int>();
      result.add(
        Ivs(
          hp: ivs[0],
          attack: ivs[1],
          defense: ivs[2],
          specialAttack: ivs[3],
          specialDefense: ivs[4],
          speed: ivs[5],
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toString();
    return FutureBuilder<_HuntData>(
      future: _HuntData.load(localeName),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.breeding,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('${_result?.results.length ?? 0}'),
              ],
            ),
            const SizedBox(height: 12),
            if (data == null)
              const LinearProgressIndicator()
            else ...[
              Builder(
                builder: (context) {
                  _syncEggSpeciesController(data);
                  return const SizedBox.shrink();
                },
              ),
              _HoverSurface(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    spacing: 10,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _speciesAutocomplete(data, l10n),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _searching
                              ? null
                              : _resetEggSettingsToDefaults,
                          icon: const Icon(Icons.restart_alt),
                          label: Text(l10n.resetDefaults),
                        ),
                      ),
                      _twoColumnFields([
                        _eggMethodDropdown(l10n),
                        _compatibilityDropdown(l10n),
                      ]),
                      if (widget.profile.game == GameVersion.emerald)
                        _twoColumnFields([
                          _numberField(
                            controller: _calibrationController,
                            label: l10n.calibration,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  controller: _minRedrawController,
                                  label: l10n.minRedraws,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _numberField(
                                  controller: _maxRedrawController,
                                  label: l10n.maxRedraws,
                                ),
                              ),
                            ],
                          ),
                        ]),
                      if (widget.profile.game == GameVersion.emerald)
                        Text(
                          l10n.eggRedrawHelp,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      _stageFields(
                        title: l10n.eggHeldStage,
                        helpText: _eggHeldStageHelp(l10n),
                        seedController: _heldSeedController,
                        initialController: _heldInitialController,
                        maxController: _heldMaxController,
                        offsetController: _heldOffsetController,
                        showSeed: widget.profile.game != GameVersion.emerald,
                      ),
                      _stageFields(
                        title: l10n.eggPickupStage,
                        helpText: _eggPickupStageHelp(l10n),
                        seedController: _pickupSeedController,
                        initialController: _pickupInitialController,
                        maxController: _pickupMaxController,
                        offsetController: _pickupOffsetController,
                        showSeed: widget.profile.game != GameVersion.emerald,
                      ),
                      Column(
                        spacing: 3,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.eggSearchRangeNote(
                              _maxEggAdvanceDelta,
                              _maxDisplayedResults,
                            ),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            _eggSearchCostEstimate(l10n),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (_eggSearchIsLarge())
                            Text(
                              l10n.eggLargeSearchWarning,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                            ),
                        ],
                      ),
                      const Divider(height: 18),
                      _parentEditor(data, l10n, 0),
                      _parentEditor(data, l10n, 1),
                      const Divider(height: 18),
                      _filters(data, l10n),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _searching ? null : () => _search(data),
                          icon: Icon(
                            _searching ? Icons.hourglass_empty : Icons.search,
                          ),
                          label: Text(
                            _searching ? l10n.searching : l10n.search,
                          ),
                        ),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _eggResults(data, l10n),
            ],
          ],
        );
      },
    );
  }

  Widget _speciesAutocomplete(_HuntData data, AppLocalizations l10n) {
    return _AutocompleteOptionsPrimer(
      controller: _pokemonController,
      focusNode: _pokemonFocusNode,
      token: data.localeName,
      child: RawAutocomplete<_SpeciesOption>(
        textEditingController: _pokemonController,
        focusNode: _pokemonFocusNode,
        displayStringForOption: (option) => option.displayName,
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) {
            return data.speciesOptions.take(_maxSpeciesSuggestions);
          }
          final numericStart = _numericSpeciesStart(query);
          if (numericStart != null) {
            if (numericStart > data.speciesOptions.length) {
              return const Iterable<_SpeciesOption>.empty();
            }
            return data.speciesOptions
                .skip(numericStart - 1)
                .take(_maxSpeciesSuggestions);
          }
          return data.speciesOptions
              .where((option) => option.searchText.contains(query))
              .take(_maxSpeciesSuggestions);
        },
        onSelected: (option) {
          _updateEggSettings(() {
            _speciesId = option.speciesId;
            _pokemonController.text = option.displayName;
            _abilitySlot = null;
            _gender = null;
          });
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: l10n.pokemon,
              border: _controlBorder,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(_controlRadius),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 240,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(option.displayName),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _syncEggSpeciesController(_HuntData data) {
    final speciesId = _speciesId;
    if (speciesId == null || _pokemonFocusNode.hasFocus) {
      return;
    }
    final displayName = data.speciesDisplayName(speciesId);
    if (_pokemonController.text != displayName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _speciesId != speciesId || _pokemonFocusNode.hasFocus) {
          return;
        }
        _suppressSettingsSave = true;
        _pokemonController.text = displayName;
        _suppressSettingsSave = false;
      });
    }
  }

  Widget _eggMethodDropdown(AppLocalizations l10n) {
    final methods = _eggMethodsForGame(widget.profile.game);
    return DropdownButtonFormField<EggMethod3>(
      isExpanded: true,
      initialValue: methods.contains(_method) ? _method : methods.first,
      decoration: InputDecoration(
        labelText: l10n.method,
        border: _controlBorder,
      ),
      items: methods
          .map(
            (method) => DropdownMenuItem<EggMethod3>(
              value: method,
              child: Text(_eggMethodLabel(method)),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) {
          _updateEggSettings(() => _method = value);
        }
      },
    );
  }

  Widget _compatibilityDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _compatibility,
      decoration: InputDecoration(
        labelText: l10n.compatibility,
        border: _controlBorder,
      ),
      items: const [20, 50, 70]
          .map(
            (value) =>
                DropdownMenuItem<int>(value: value, child: Text('$value')),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) {
          _updateEggSettings(() => _compatibility = value);
        }
      },
    );
  }

  Widget _stageFields({
    required String title,
    required String helpText,
    required TextEditingController seedController,
    required TextEditingController initialController,
    required TextEditingController maxController,
    required TextEditingController offsetController,
    required bool showSeed,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        Text(helpText, style: Theme.of(context).textTheme.labelSmall),
        if (showSeed)
          TextField(
            controller: seedController,
            decoration: InputDecoration(labelText: l10n.seed),
          ),
        _twoColumnFields([
          _numberField(
            controller: initialController,
            label: l10n.initialAdvance,
          ),
          _numberField(controller: maxController, label: l10n.maxAdvance),
        ]),
        _numberField(controller: offsetController, label: 'Offset'),
      ],
    );
  }

  String _eggHeldStageHelp(AppLocalizations l10n) {
    return widget.profile.game == GameVersion.emerald
        ? l10n.eggHeldStageHelpEmerald
        : l10n.eggHeldStageHelpFrlg;
  }

  String _eggPickupStageHelp(AppLocalizations l10n) {
    return widget.profile.game == GameVersion.emerald
        ? l10n.eggPickupStageHelpEmerald
        : l10n.eggPickupStageHelpFrlg;
  }

  Widget _parentEditor(_HuntData data, AppLocalizations l10n, int index) {
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          index == 0 ? l10n.parentA : l10n.parentB,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        _twoColumnFields([
          DropdownButtonFormField<DaycareParentGender>(
            isExpanded: true,
            initialValue: _parentGenders[index],
            decoration: InputDecoration(
              labelText: l10n.parentGender,
              border: _controlBorder,
            ),
            items: DaycareParentGender.values
                .map(
                  (gender) => DropdownMenuItem<DaycareParentGender>(
                    value: gender,
                    child: Text(_parentGenderLabel(context, gender)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                _updateEggSettings(() => _parentGenders[index] = value);
              }
            },
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _parentItems[index],
            decoration: InputDecoration(
              labelText: l10n.parentItem,
              border: _controlBorder,
            ),
            items: [
              DropdownMenuItem<int>(value: 0, child: Text(l10n.none)),
              DropdownMenuItem<int>(value: 1, child: Text(l10n.everstone)),
            ],
            onChanged: (value) {
              if (value != null) {
                _updateEggSettings(() => _parentItems[index] = value);
              }
            },
          ),
        ]),
        DropdownButtonFormField<Nature>(
          isExpanded: true,
          initialValue: _parentNatures[index],
          decoration: InputDecoration(labelText: l10n.nature),
          items: Nature.values
              .map(
                (nature) => DropdownMenuItem<Nature>(
                  value: nature,
                  child: Text(
                    data.natureLabel(context, nature),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              _updateEggSettings(() => _parentNatures[index] = value);
            }
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(6, (stat) {
            return SizedBox(
              width: 82,
              child: TextField(
                controller: _parentIvControllers[index][stat],
                decoration: InputDecoration(labelText: _shortIvLabel(stat)),
                keyboardType: TextInputType.number,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _filters(_HuntData data, AppLocalizations l10n) {
    final personal = _speciesId == null ? null : data.personal[_speciesId!];
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _shinyOnly,
          title: Text(l10n.shiny),
          onChanged: (value) => _updateEggSettings(() => _shinyOnly = value),
        ),
        _twoColumnFields([
          DropdownButtonFormField<Nature?>(
            isExpanded: true,
            initialValue: _nature,
            decoration: InputDecoration(labelText: l10n.nature),
            items: [
              DropdownMenuItem<Nature?>(value: null, child: Text(l10n.any)),
              ...Nature.values.map(
                (nature) => DropdownMenuItem<Nature?>(
                  value: nature,
                  child: Text(
                    data.natureLabel(context, nature),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => _updateEggSettings(() => _nature = value),
          ),
          DropdownButtonFormField<HiddenPowerType?>(
            isExpanded: true,
            initialValue: _hiddenPowerType,
            decoration: InputDecoration(labelText: l10n.hiddenPower),
            items: [
              DropdownMenuItem<HiddenPowerType?>(
                value: null,
                child: Text(l10n.any),
              ),
              ...HiddenPowerType.values.map(
                (type) => DropdownMenuItem<HiddenPowerType?>(
                  value: type,
                  child: Text(_hiddenPowerTypeLabel(context, type)),
                ),
              ),
            ],
            onChanged: (value) =>
                _updateEggSettings(() => _hiddenPowerType = value),
          ),
        ]),
        _twoColumnFields([
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _abilitySlot,
            decoration: InputDecoration(labelText: l10n.ability),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l10n.any)),
              if (personal != null)
                for (var slot = 0; slot < personal.abilityIds.length; slot += 1)
                  DropdownMenuItem<int?>(
                    value: slot,
                    child: Text(
                      _abilitySlotLabel(
                        context: context,
                        slot: slot,
                        name: data.names.abilityName(personal.abilityIds[slot]),
                      ),
                    ),
                  ),
            ],
            onChanged: (value) =>
                _updateEggSettings(() => _abilitySlot = value),
          ),
          DropdownButtonFormField<PokemonGender?>(
            isExpanded: true,
            initialValue: _gender,
            decoration: InputDecoration(labelText: l10n.gender),
            items: [
              DropdownMenuItem<PokemonGender?>(
                value: null,
                child: Text(l10n.any),
              ),
              for (final gender in _legalGenders(personal))
                DropdownMenuItem<PokemonGender?>(
                  value: gender,
                  child: Text(_genderLabel(gender)),
                ),
            ],
            onChanged: (value) => _updateEggSettings(() => _gender = value),
          ),
        ]),
        Text(l10n.ivs, style: Theme.of(context).textTheme.labelLarge),
        _IvInputGrid(
          controllers: _ivControllers,
          comparisons: _ivComparisons,
          onComparisonChanged: (index, value) {
            _updateEggSettings(() => _ivComparisons[index] = value);
          },
        ),
      ],
    );
  }

  Widget _eggResults(_HuntData data, AppLocalizations l10n) {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    if (result.results.isEmpty) {
      return _HoverSurface(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l10n.noResults),
        ),
      );
    }
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.resultLimitReached)
          Text(l10n.resultLimitNote(_maxDisplayedResults)),
        for (final state in result.results)
          _HoverSurface(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _EggResultTile(state: state, data: data),
            ),
          ),
      ],
    );
  }

  Widget _twoColumnFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420 || children.length == 1) {
          return Column(spacing: 8, children: children);
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i += 1) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
    );
  }

  String _eggSearchCostEstimate(AppLocalizations l10n) {
    final count = _eggSearchCombinationCount();
    final formatted = count == null ? '-' : _formatInteger(count);
    if (widget.profile.game == GameVersion.emerald) {
      return l10n.eggSearchCostEstimate(formatted);
    }
    return l10n.eggSearchCostEstimateFrlg(formatted);
  }

  bool _eggSearchIsLarge() {
    final count = _eggSearchCombinationCount();
    return count != null && count > _largeEggSearchCombinationThreshold;
  }

  BigInt? _eggSearchCombinationCount() {
    final heldInitial = int.tryParse(_heldInitialController.text.trim());
    final heldMax = int.tryParse(_heldMaxController.text.trim());
    final pickupInitial = int.tryParse(_pickupInitialController.text.trim());
    final pickupMax = int.tryParse(_pickupMaxController.text.trim());
    final minRedraw = int.tryParse(_minRedrawController.text.trim());
    final maxRedraw = int.tryParse(_maxRedrawController.text.trim());
    if (heldInitial == null ||
        heldMax == null ||
        pickupInitial == null ||
        pickupMax == null ||
        minRedraw == null ||
        maxRedraw == null ||
        heldMax < heldInitial ||
        pickupMax < pickupInitial ||
        maxRedraw < minRedraw) {
      return null;
    }
    final heldCount = BigInt.from(heldMax - heldInitial + 1);
    final pickupCount = BigInt.from(pickupMax - pickupInitial + 1);
    final redrawCount = widget.profile.game == GameVersion.emerald
        ? BigInt.from(maxRedraw - minRedraw + 1)
        : BigInt.one;
    return heldCount * pickupCount * redrawCount;
  }
}

class _EggResultTile extends StatelessWidget {
  const _EggResultTile({required this.state, required this.data});

  final EggState3 state;
  final _HuntData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hiddenPower = state.ivs.hiddenPower;
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ResultField(
                label: l10n.eggHeldStage,
                value: '${state.advances}',
              ),
            ),
            Expanded(
              child: _ResultField(
                label: l10n.eggPickupStage,
                value: '${state.pickupAdvances}',
              ),
            ),
            Expanded(
              child: _ResultField(
                label: l10n.redraws,
                value: '${state.redraws}',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ResultField(
                label: l10n.pokemon,
                value: data.names.speciesName(state.species),
              ),
            ),
            Expanded(
              child: _ResultField(
                label: l10n.gender,
                value: state.shiny
                    ? '${_genderLabel(state.gender)} ✨'
                    : _genderLabel(state.gender),
              ),
            ),
            Expanded(
              child: _ResultField(
                label: l10n.nature,
                value: data.names.natureName(state.nature),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ResultField(
                label: l10n.hiddenPower,
                value:
                    '${_hiddenPowerTypeLabel(context, hiddenPower.type)} ${hiddenPower.power}',
              ),
            ),
            Expanded(
              flex: 2,
              child: _ResultField(label: l10n.ivs, value: '${state.ivs}'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ResultField(label: 'PID', value: '${state.pid}'),
            ),
            Expanded(
              flex: 2,
              child: _ResultField(label: l10n.stats, value: '${state.stats}'),
            ),
          ],
        ),
        _ResultField(
          label: l10n.inheritance,
          value: _eggInheritanceSummary(context, state.inheritance),
        ),
      ],
    );
  }
}

class _ToolsPage extends StatelessWidget {
  const _ToolsPage({
    required this.savedTargets,
    required this.onUseTarget,
    required this.onDeleteTarget,
  });

  final List<_SavedTarget> savedTargets;
  final ValueChanged<_SavedTarget> onUseTarget;
  final ValueChanged<_SavedTarget> onDeleteTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.savedTargets,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text('${savedTargets.length}'),
          ],
        ),
        const SizedBox(height: 12),
        if (savedTargets.isEmpty)
          _HoverSurface(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n.noSavedTargets),
            ),
          )
        else
          ...savedTargets.map(
            (saved) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SavedTargetTile(
                saved: saved,
                onUse: () => onUseTarget(saved),
                onDelete: () => onDeleteTarget(saved),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(l10n.tools, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _StatIvCalculator(),
      ],
    );
  }
}

class _SavedTargetTile extends StatelessWidget {
  const _SavedTargetTile({
    required this.saved,
    required this.onUse,
    required this.onDelete,
  });

  final _SavedTarget saved;
  final VoidCallback? onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hiddenPower = saved.ivs.hiddenPower;
    return _HoverSurface(
      child: ListTile(
        dense: true,
        onTap: onUse,
        title: Row(
          children: [
            Flexible(
              child: Text(
                '#${saved.species} ${saved.names.speciesName(saved.species)} · '
                '${l10n.resultAdvance} ${saved.advance}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (saved.shiny) const _ShinyIcon(),
          ],
        ),
        subtitle: Text(
          '${saved.kindLabel(context)} · '
          '${l10n.levelShort} ${saved.level} · '
          '${_genderLabel(saved.gender)} · '
          '${saved.names.natureName(saved.nature)} · '
          '${_hiddenPowerTypeLabel(context, hiddenPower.type)} ${hiddenPower.power}',
        ),
        trailing: IconButton(
          tooltip: l10n.deleteTarget,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _StatIvCalculator extends StatefulWidget {
  const _StatIvCalculator();

  @override
  State<_StatIvCalculator> createState() => _StatIvCalculatorState();
}

class _StatIvCalculatorState extends State<_StatIvCalculator> {
  final _pokemonController = TextEditingController();
  final _pokemonFocusNode = FocusNode();
  final _levelController = TextEditingController(text: '50');
  final _ivControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(text: '31'),
  );
  final _statControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  int? _speciesId;
  Nature _nature = Nature.hardy;
  PokemonStats? _calculatedStats;
  List<String>? _calculatedIvRanges;
  String? _error;

  @override
  void dispose() {
    _pokemonController.dispose();
    _pokemonFocusNode.dispose();
    _levelController.dispose();
    for (final controller in _ivControllers) {
      controller.dispose();
    }
    for (final controller in _statControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateStats(_HuntData data) {
    final personal = _speciesId == null ? null : data.personal[_speciesId!];
    final level = int.tryParse(_levelController.text.trim());
    final ivs = _parseIvs(_ivControllers);
    if (personal == null ||
        level == null ||
        level < 1 ||
        level > 100 ||
        ivs == null) {
      setState(() {
        _error = AppLocalizations.of(context)!.calculatorInputError;
        _calculatedStats = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _calculatedStats = calculateGen3Stats(
        personalInfo: personal,
        ivs: ivs,
        nature: _nature,
        level: level,
      );
    });
  }

  void _calculateIvs(_HuntData data) {
    final personal = _speciesId == null ? null : data.personal[_speciesId!];
    final level = int.tryParse(_levelController.text.trim());
    final stats = _parseStats(_statControllers);
    if (personal == null ||
        level == null ||
        level < 1 ||
        level > 100 ||
        stats == null) {
      setState(() {
        _error = AppLocalizations.of(context)!.calculatorInputError;
        _calculatedIvRanges = null;
      });
      return;
    }
    final ranges = _possibleIvRanges(
      personalInfo: personal,
      stats: stats,
      nature: _nature,
      level: level,
    );
    setState(() {
      _error = null;
      _calculatedIvRanges = ranges;
    });
  }

  Ivs? _parseIvs(List<TextEditingController> controllers) {
    final values = controllers
        .map((controller) => int.tryParse(controller.text.trim()))
        .toList();
    if (values.any((value) => value == null || value < 0 || value > 31)) {
      return null;
    }
    final ivs = values.cast<int>();
    return Ivs(
      hp: ivs[0],
      attack: ivs[1],
      defense: ivs[2],
      specialAttack: ivs[3],
      specialDefense: ivs[4],
      speed: ivs[5],
    );
  }

  PokemonStats? _parseStats(List<TextEditingController> controllers) {
    final values = controllers
        .map((controller) => int.tryParse(controller.text.trim()))
        .toList();
    if (values.any((value) => value == null || value < 1)) {
      return null;
    }
    final stats = values.cast<int>();
    return PokemonStats(
      hp: stats[0],
      attack: stats[1],
      defense: stats[2],
      specialAttack: stats[3],
      specialDefense: stats[4],
      speed: stats[5],
    );
  }

  List<String> _possibleIvRanges({
    required Gen3PersonalInfo personalInfo,
    required PokemonStats stats,
    required Nature nature,
    required int level,
  }) {
    final possible = possibleGen3IvValuesForStats(
      personalInfo: personalInfo,
      stats: stats,
      nature: nature,
      level: level,
    );
    return possible.map(_rangeLabel).toList(growable: false);
  }

  String _rangeLabel(List<int> values) {
    if (values.isEmpty) {
      return '-';
    }
    final ranges = <String>[];
    var start = values.first;
    var previous = values.first;
    for (final value in values.skip(1)) {
      if (value == previous + 1) {
        previous = value;
        continue;
      }
      ranges.add(start == previous ? '$start' : '$start-$previous');
      start = value;
      previous = value;
    }
    ranges.add(start == previous ? '$start' : '$start-$previous');
    return ranges.join(', ');
  }

  List<Widget> _numberFields({
    required AppLocalizations l10n,
    required List<TextEditingController> controllers,
  }) {
    final labels = _statLabels(l10n);
    return List<Widget>.generate(labels.length, (index) {
      return SizedBox(
        width: 96,
        child: _ClearOnFirstFocusTextField(
          controller: controllers[index],
          decoration: InputDecoration(
            labelText: labels[index],
            border: _controlBorder,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );
    }, growable: false);
  }

  List<String> _statLabels(AppLocalizations l10n) {
    return [
      'HP',
      l10n.statAttack,
      l10n.statDefense,
      l10n.statSpecialAttack,
      l10n.statSpecialDefense,
      l10n.statSpeed,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<_HuntData>(
      future: _HuntData.load(localeName),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return _HoverSurface(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.statIvCalculator,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (data == null)
                  const LinearProgressIndicator()
                else ...[
                  _AutocompleteOptionsPrimer(
                    controller: _pokemonController,
                    focusNode: _pokemonFocusNode,
                    token: data.localeName,
                    child: RawAutocomplete<_SpeciesOption>(
                      textEditingController: _pokemonController,
                      focusNode: _pokemonFocusNode,
                      displayStringForOption: (option) => option.displayName,
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text
                            .trim()
                            .toLowerCase();
                        if (query.isEmpty) {
                          return data.speciesOptions.take(
                            _maxSpeciesSuggestions,
                          );
                        }
                        final numericStart = _numericSpeciesStart(query);
                        if (numericStart != null) {
                          if (numericStart > data.speciesOptions.length) {
                            return const Iterable<_SpeciesOption>.empty();
                          }
                          return data.speciesOptions
                              .skip(numericStart - 1)
                              .take(_maxSpeciesSuggestions);
                        }
                        return data.speciesOptions
                            .where(
                              (option) => option.searchText.contains(query),
                            )
                            .take(_maxSpeciesSuggestions);
                      },
                      onSelected: (option) {
                        setState(() {
                          _speciesId = option.speciesId;
                          _pokemonController.text = option.displayName;
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: l10n.pokemon,
                                border: _controlBorder,
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(_controlRadius),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 360,
                                maxHeight: 240,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Text(option.displayName),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _levelController,
                          decoration: InputDecoration(
                            labelText: l10n.levelShort,
                            border: _controlBorder,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<Nature>(
                          isExpanded: true,
                          initialValue: _nature,
                          decoration: InputDecoration(
                            labelText: l10n.nature,
                            border: _controlBorder,
                          ),
                          items: Nature.values
                              .map(
                                (nature) => DropdownMenuItem<Nature>(
                                  value: nature,
                                  child: Text(
                                    data.natureLabel(context, nature),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _nature = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(l10n.ivs, style: Theme.of(context).textTheme.labelLarge),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _numberFields(
                      l10n: l10n,
                      controllers: _ivControllers,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _calculateStats(data),
                    child: Text(l10n.calculateStats),
                  ),
                  if (_calculatedStats != null)
                    Text('${l10n.stats}: $_calculatedStats'),
                  const Divider(height: 20),
                  Text(
                    l10n.stats,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _numberFields(
                      l10n: l10n,
                      controllers: _statControllers,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _calculateIvs(data),
                    child: Text(l10n.calculateIvs),
                  ),
                  if (_calculatedIvRanges != null)
                    Text(
                      _statLabels(l10n)
                          .asMap()
                          .entries
                          .map(
                            (entry) =>
                                '${entry.value}: ${_calculatedIvRanges![entry.key]}',
                          )
                          .join(' / '),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.profile,
    required this.profiles,
    required this.onProfileChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppProfile profile;
  final Map<GameVersion, AppProfile> profiles;
  final ValueChanged<AppProfile> onProfileChanged;
  final _AppLanguage language;
  final ValueChanged<_AppLanguage> onLanguageChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SupportProduct {
  const _SupportProduct({
    required this.id,
    required this.displayName,
    required this.price,
  });

  factory _SupportProduct.fromPlatform(Map<dynamic, dynamic> json) {
    return _SupportProduct(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      price: json['price'] as String,
    );
  }

  final String id;
  final String displayName;
  final String price;
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _tidController;
  late final TextEditingController _sidController;
  late final TextEditingController _seedController;
  late GameVersion _game;
  String _appVersion = '-';
  String? _error;

  @override
  void initState() {
    super.initState();
    _game = widget.profile.game;
    _tidController = TextEditingController(text: '${widget.profile.tid}');
    _sidController = TextEditingController(text: '${widget.profile.sid}');
    _seedController = TextEditingController(text: widget.profile.defaultSeed);
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _appVersion = info.buildNumber.isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})';
    });
  }

  @override
  void dispose() {
    _tidController.dispose();
    _sidController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _game = widget.profile.game;
      _applyProfile(widget.profile);
    }
  }

  void _applyProfile(AppProfile profile) {
    _tidController.text = '${profile.tid}';
    _sidController.text = '${profile.sid}';
    _seedController.text = profile.defaultSeed;
  }

  void _save() {
    final tid = int.tryParse(_tidController.text.trim());
    final sid = int.tryParse(_sidController.text.trim());
    final seed = _seedController.text.trim();

    if (tid == null ||
        sid == null ||
        tid < 0 ||
        tid > 65535 ||
        sid < 0 ||
        sid > 65535 ||
        int.tryParse(seed.replaceFirst(RegExp('^0x'), ''), radix: 16) == null) {
      setState(() => _error = AppLocalizations.of(context)!.settingsInputError);
      return;
    }

    widget.onProfileChanged(
      AppProfile(game: _game, tid: tid, sid: sid, defaultSeed: seed),
    );
    setState(() => _error = null);
  }

  void _copyProjectUrl() {
    Clipboard.setData(const ClipboardData(text: _projectUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.projectUrlCopied)),
    );
  }

  bool get _supportsApplePurchases {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _openSupportPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _SupportPage()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        DropdownButtonFormField<_AppLanguage>(
          isExpanded: true,
          initialValue: widget.language,
          decoration: InputDecoration(
            labelText: l10n.language,
            prefixIcon: const Icon(Icons.language),
            border: _controlBorder,
          ),
          items: _AppLanguage.values
              .map(
                (language) => DropdownMenuItem<_AppLanguage>(
                  value: language,
                  child: Text(_languageLabel(l10n, language)),
                ),
              )
              .toList(),
          onChanged: (language) {
            if (language != null) {
              widget.onLanguageChanged(language);
            }
          },
        ),
        const SizedBox(height: 20),
        Text(l10n.gameVersion, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<GameVersion>(
          segments: GameVersion.values
              .map(
                (game) => ButtonSegment<GameVersion>(
                  value: game,
                  label: Text(game.label),
                ),
              )
              .toList(),
          selected: {_game},
          onSelectionChanged: (selection) {
            setState(() {
              _game = selection.first;
              _applyProfile(
                widget.profiles[_game] ?? AppProfile.defaultsFor(_game),
              );
            });
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tidController,
                decoration: const InputDecoration(
                  labelText: 'TID',
                  prefixIcon: Icon(Icons.badge),
                  border: _controlBorder,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sidController,
                decoration: const InputDecoration(
                  labelText: 'SID',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: _controlBorder,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _seedController,
          decoration: InputDecoration(
            labelText: l10n.defaultSeed,
            prefixIcon: const Icon(Icons.tag),
            border: _controlBorder,
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(l10n.save),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 32),
        if (_supportsApplePurchases) ...[
          _supportEntry(l10n),
          const SizedBox(height: 24),
        ],
        _aboutSection(l10n),
      ],
    );
  }

  Widget _supportEntry(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return _HoverSurface(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Icon(Icons.favorite_border, color: theme.colorScheme.primary),
        title: Text(l10n.supportDeveloper),
        subtitle: Text(l10n.supportNoUnlock),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openSupportPage,
      ),
    );
  }

  Widget _aboutSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.about, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _HoverSurface(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(l10n.aboutDescription),
                const SizedBox(height: 4),
                Text(l10n.unofficialNotice, style: theme.textTheme.labelMedium),
                const SizedBox(height: 14),
                _aboutRow(l10n.version, _appVersion),
                _aboutRow(l10n.license, _appLicense),
                _aboutRow(l10n.project, _projectUrl, selectable: true),
                _aboutRow(
                  l10n.privacyPolicy,
                  _privacyPolicyUrl,
                  selectable: true,
                ),
                const SizedBox(height: 10),
                Text(l10n.credits, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(l10n.aboutCredits),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyProjectUrl,
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copyProjectUrl),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aboutRow(String label, String value, {bool selectable = false}) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium;
    final valueWidget = selectable
        ? SelectableText(value, style: valueStyle)
        : Text(value, style: valueStyle);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _SupportPage extends StatefulWidget {
  const _SupportPage();

  @override
  State<_SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<_SupportPage> {
  List<_SupportProduct> _products = const [];
  bool _loading = false;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (_loading) {
      return;
    }
    if (kIsWeb) {
      setState(() {
        _products = const [];
        _error = AppLocalizations.of(context)!.supportUnavailable;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _supportPurchaseChannel
          .invokeMethod<List<dynamic>>('products', {'ids': _supportProductIds});
      final parsed = (products ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(_SupportProduct.fromPlatform)
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _products = parsed;
        _error = parsed.isEmpty
            ? AppLocalizations.of(context)!.supportUnavailable
            : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _products = const [];
        _error = AppLocalizations.of(context)!.supportUnavailable;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _buy(_SupportProduct product) async {
    if (_purchasing) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _purchasing = true);
    try {
      final status = await _supportPurchaseChannel.invokeMethod<String>(
        'purchase',
        {'id': product.id},
      );
      if (!mounted) {
        return;
      }
      final message = switch (status) {
        'success' => l10n.supportThanks,
        'pending' => l10n.supportPending,
        'cancelled' => l10n.supportCancelled,
        _ => l10n.supportFailed,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.supportFailed)));
    } finally {
      if (mounted) {
        setState(() => _purchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportDeveloper)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.supportDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(l10n.supportNoUnlock, style: theme.textTheme.labelMedium),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_products.isEmpty) ...[
            _HoverSurface(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error ?? l10n.supportUnavailable),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ] else
            ..._products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HoverSurface(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: Icon(
                      Icons.favorite_border,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(product.displayName),
                    subtitle: Text(product.price),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_purchasing,
                    onTap: _purchasing ? null : () => _buy(product),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _languageLabel(AppLocalizations l10n, _AppLanguage language) {
  return switch (language) {
    _AppLanguage.system => l10n.languageSystem,
    _AppLanguage.zhHans => l10n.languageChineseSimplified,
    _AppLanguage.en => l10n.languageEnglish,
    _AppLanguage.ja => l10n.languageJapanese,
  };
}

void _refreshAutocompleteOptions(TextEditingController controller) {
  final value = controller.value;
  final transientText = '${value.text} ';
  controller.value = TextEditingValue(
    text: transientText,
    selection: TextSelection.collapsed(offset: transientText.length),
  );
  controller.value = value;
}

String _assetLocaleForDisplayLocale(String localeName) {
  return switch (localeName) {
    'zh' || 'zh_CN' || 'zh_Hans' || 'zh_Hans_CN' => 'zh_Hans',
    'ja' || 'ja_JP' => 'ja',
    _ => 'en',
  };
}

class _AutocompleteOptionsPrimer extends StatefulWidget {
  const _AutocompleteOptionsPrimer({
    required this.controller,
    required this.focusNode,
    required this.token,
    required this.child,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Object token;
  final Widget child;

  @override
  State<_AutocompleteOptionsPrimer> createState() =>
      _AutocompleteOptionsPrimerState();
}

class _AutocompleteOptionsPrimerState
    extends State<_AutocompleteOptionsPrimer> {
  @override
  void initState() {
    super.initState();
    _schedulePrime();
  }

  @override
  void didUpdateWidget(covariant _AutocompleteOptionsPrimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.controller != widget.controller) {
      _schedulePrime();
    }
  }

  void _schedulePrime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.focusNode.hasFocus) {
        return;
      }
      _refreshAutocompleteOptions(widget.controller);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

Locale _resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  const english = Locale('en');
  const japanese = Locale('ja');
  const simplifiedChinese = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  );

  final preferred = preferredLocales?.isEmpty ?? true
      ? null
      : preferredLocales!.first;
  if (preferred == null) {
    return english;
  }

  if (preferred.languageCode == 'en') {
    return english;
  }
  if (preferred.languageCode == 'ja') {
    return japanese;
  }
  if (preferred.languageCode == 'zh' &&
      (preferred.scriptCode == 'Hans' ||
          preferred.countryCode == 'CN' ||
          preferred.countryCode == 'SG' ||
          (preferred.scriptCode == null && preferred.countryCode == null))) {
    return simplifiedChinese;
  }

  return english;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ResultField extends StatelessWidget {
  const _ResultField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _HuntSearchSnapshot {
  const _HuntSearchSnapshot({
    required this.seed,
    required this.initialAdvance,
    required this.maxAdvance,
    required this.delay,
    required this.ivFilter,
    required this.shinyOnly,
    required this.nature,
    required this.hiddenPowerType,
    required this.abilitySlot,
    required this.gender,
    required this.encounterSlot,
    required this.synchronizeNature,
    required this.pressureLead,
    required this.staticLead,
    required this.magnetPullLead,
    required this.cuteCharmLead,
    required this.feebasTile,
    required this.speciesId,
    required this.area,
    required this.method,
    required this.personalData,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvance;
  final int delay;
  final IvFilter ivFilter;
  final bool shinyOnly;
  final Nature? nature;
  final HiddenPowerType? hiddenPowerType;
  final int? abilitySlot;
  final PokemonGender? gender;
  final int? encounterSlot;
  final Nature? synchronizeNature;
  final bool pressureLead;
  final bool staticLead;
  final bool magnetPullLead;
  final CuteCharmLead? cuteCharmLead;
  final bool feebasTile;
  final int speciesId;
  final WildEncounterArea area;
  final WildMethod method;
  final Gen3PersonalData personalData;
}

class _StaticSearchSnapshot {
  const _StaticSearchSnapshot({
    required this.seed,
    required this.initialAdvance,
    required this.maxAdvance,
    required this.delay,
    required this.method,
    required this.template,
    required this.personalData,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvance;
  final int delay;
  final StaticMethod method;
  final StaticEncounterTemplate template;
  final Gen3PersonalData personalData;
}

sealed class _CalibrationPageTarget {
  const _CalibrationPageTarget();

  Gen3NamedResources get names;
  int get advance;
  int get delay;
  int get species;
  int get level;
  PokemonPid get pid;
  Nature get nature;
  PokemonGender get gender;
  Ivs get ivs;
  bool get shiny;
  Gen3PersonalData get personalData;
  String kindLabel(BuildContext context);
}

class _CalibrationTarget extends _CalibrationPageTarget {
  const _CalibrationTarget({
    required this.search,
    required this.state,
    required this.names,
  });

  final _HuntSearchSnapshot search;
  final WildState state;
  @override
  final Gen3NamedResources names;

  @override
  int get advance => state.advance;

  @override
  int get delay => search.delay;

  @override
  int get species => state.species;

  @override
  int get level => state.level;

  @override
  PokemonPid get pid => state.pid;

  @override
  Nature get nature => state.nature;

  @override
  PokemonGender get gender => state.gender;

  @override
  Ivs get ivs => state.ivs;

  @override
  bool get shiny => state.shiny;

  @override
  Gen3PersonalData get personalData => search.personalData;

  @override
  String kindLabel(BuildContext context) {
    return _encounterTypeLabel(context, search.area.type);
  }
}

class _StaticTarget extends _CalibrationPageTarget {
  const _StaticTarget({
    required this.search,
    required this.hit,
    required this.names,
  });

  final _StaticSearchSnapshot search;
  final StaticSearchHit hit;
  @override
  final Gen3NamedResources names;

  @override
  int get advance => hit.state.advance;

  @override
  int get delay => search.delay;

  @override
  int get species => hit.template.species;

  @override
  int get level => hit.state.level;

  @override
  PokemonPid get pid => hit.state.pid;

  @override
  Nature get nature => hit.state.nature;

  @override
  PokemonGender get gender => hit.state.gender;

  @override
  Ivs get ivs => hit.state.ivs;

  @override
  bool get shiny => hit.state.shiny;

  @override
  Gen3PersonalData get personalData => search.personalData;

  @override
  String kindLabel(BuildContext context) {
    return _staticEncounterTypeLabel(context, hit.template.type);
  }
}

sealed class _SavedTarget {
  const _SavedTarget();

  int get id;
  DateTime get savedAt;
  Gen3NamedResources get names;
  int get species;
  int get advance;
  int get level;
  Nature get nature;
  PokemonGender get gender;
  Ivs get ivs;
  bool get shiny;
  String get duplicateKey;
  String kindLabel(BuildContext context);
}

class _SavedCalibrationTarget extends _SavedTarget {
  const _SavedCalibrationTarget({
    required this.id,
    required this.target,
    required this.savedAt,
  });

  @override
  final int id;
  final _CalibrationTarget target;
  @override
  final DateTime savedAt;

  @override
  Gen3NamedResources get names => target.names;

  @override
  int get species => target.state.species;

  @override
  int get advance => target.state.advance;

  @override
  int get level => target.state.level;

  @override
  Nature get nature => target.state.nature;

  @override
  PokemonGender get gender => target.state.gender;

  @override
  Ivs get ivs => target.state.ivs;

  @override
  bool get shiny => target.state.shiny;

  @override
  String get duplicateKey {
    final area = target.search.area;
    return [
      'wild',
      area.game.jsonName,
      area.locationId,
      area.type.jsonName,
      target.search.method.index,
      target.state.species,
      target.state.encounterSlot,
      target.state.advance,
      target.state.pid.value,
    ].join(':');
  }

  @override
  String kindLabel(BuildContext context) {
    return _encounterTypeLabel(context, target.search.area.type);
  }
}

class _SavedStaticTarget extends _SavedTarget {
  const _SavedStaticTarget({
    required this.id,
    required this.target,
    required this.savedAt,
  });

  @override
  final int id;
  final _StaticTarget target;
  @override
  final DateTime savedAt;

  StaticSearchHit get hit => target.hit;

  @override
  Gen3NamedResources get names => target.names;

  @override
  int get species => hit.template.species;

  @override
  int get advance => hit.state.advance;

  @override
  int get level => hit.state.level;

  @override
  Nature get nature => hit.state.nature;

  @override
  PokemonGender get gender => hit.state.gender;

  @override
  Ivs get ivs => hit.state.ivs;

  @override
  bool get shiny => hit.state.shiny;

  @override
  String get duplicateKey {
    final template = hit.template;
    return [
      'static',
      template.game.jsonName,
      template.type.jsonName,
      template.description,
      template.species,
      template.form,
      template.level,
      target.search.method.index,
      hit.state.advance,
      hit.state.pid.value,
    ].join(':');
  }

  @override
  String kindLabel(BuildContext context) {
    return _staticEncounterTypeLabel(context, hit.template.type);
  }
}

class _SavedTargetRecord {
  const _SavedTargetRecord({
    required this.id,
    required this.savedAtMs,
    required this.search,
    required this.state,
  });

  factory _SavedTargetRecord.fromSaved(_SavedTarget saved) {
    return switch (saved) {
      _SavedCalibrationTarget(:final target) => _SavedTargetRecord._fromWild(
        id: saved.id,
        savedAtMs: saved.savedAt.millisecondsSinceEpoch,
        target: target,
      ),
      _SavedStaticTarget(:final target) => _SavedTargetRecord._fromStatic(
        id: saved.id,
        savedAtMs: saved.savedAt.millisecondsSinceEpoch,
        target: target,
      ),
    };
  }

  factory _SavedTargetRecord._fromWild({
    required int id,
    required int savedAtMs,
    required _CalibrationTarget target,
  }) {
    final search = target.search;
    final state = target.state;
    return _SavedTargetRecord(
      id: id,
      savedAtMs: savedAtMs,
      search: {
        'kind': 'wild',
        'seed': search.seed,
        'initialAdvance': search.initialAdvance,
        'maxAdvance': search.maxAdvance,
        'delay': search.delay,
        'ivRules': search.ivFilter.rules
            .map(
              (rule) => {
                'value': rule.value,
                'comparison': rule.comparison.index,
              },
            )
            .toList(growable: false),
        'shinyOnly': search.shinyOnly,
        'nature': search.nature?.index,
        'hiddenPowerType': search.hiddenPowerType?.index,
        'abilitySlot': search.abilitySlot,
        'gender': search.gender?.index,
        'encounterSlot': search.encounterSlot,
        'synchronizeNature': search.synchronizeNature?.index,
        'pressureLead': search.pressureLead,
        'staticLead': search.staticLead,
        'magnetPullLead': search.magnetPullLead,
        'cuteCharmLead': search.cuteCharmLead?.index,
        'feebasTile': search.feebasTile,
        'speciesId': search.speciesId,
        'area': {
          'game': search.area.game.jsonName,
          'locationId': search.area.locationId,
          'type': search.area.type.jsonName,
        },
        'method': search.method.index,
      },
      state: _stateJson(
        advance: state.advance,
        pid: state.pid,
        ivs: state.ivs,
        nature: state.nature,
        abilitySlot: state.abilitySlot,
        gender: state.gender,
        shiny: state.shiny,
        species: state.species,
        form: state.form,
        level: state.level,
        encounterSlot: state.encounterSlot,
      ),
    );
  }

  factory _SavedTargetRecord._fromStatic({
    required int id,
    required int savedAtMs,
    required _StaticTarget target,
  }) {
    final hit = target.hit;
    final search = target.search;
    final template = hit.template;
    final state = hit.state;
    return _SavedTargetRecord(
      id: id,
      savedAtMs: savedAtMs,
      search: {
        'kind': 'static',
        'seed': search.seed,
        'initialAdvance': search.initialAdvance,
        'maxAdvance': search.maxAdvance,
        'delay': search.delay,
        'method': search.method.index,
        'template': {
          'game': template.game.jsonName,
          'type': template.type.jsonName,
          'description': template.description,
          'species': template.species,
          'form': template.form,
          'level': template.level,
          'buggedRoamer': template.buggedRoamer,
        },
      },
      state: _stateJson(
        advance: state.advance,
        seed: state.seed,
        pid: state.pid,
        ivs: state.ivs,
        nature: state.nature,
        abilitySlot: state.abilitySlot,
        gender: state.gender,
        shiny: state.shiny,
        species: template.species,
        form: template.form,
        level: state.level,
      ),
    );
  }

  static Map<String, dynamic> _stateJson({
    required int advance,
    required PokemonPid pid,
    required Ivs ivs,
    required Nature nature,
    required int abilitySlot,
    required PokemonGender gender,
    required bool shiny,
    required int species,
    required int form,
    required int level,
    int? seed,
    int? encounterSlot,
  }) {
    final json = <String, dynamic>{
      'advance': advance,
      'pid': pid.value,
      'ivs': ivs.ordered,
      'nature': nature.index,
      'abilitySlot': abilitySlot,
      'gender': gender.index,
      'shiny': shiny,
      'encounterSlot': encounterSlot,
      'species': species,
      'form': form,
      'level': level,
    };
    if (seed != null) {
      json['seed'] = seed;
    }
    return json;
  }

  factory _SavedTargetRecord.fromJson(Map<String, dynamic> json) {
    return _SavedTargetRecord(
      id: json['id'] as int,
      savedAtMs: json['savedAtMs'] as int,
      search: json['search'] as Map<String, dynamic>,
      state: json['state'] as Map<String, dynamic>,
    );
  }

  final int id;
  final int savedAtMs;
  final Map<String, dynamic> search;
  final Map<String, dynamic> state;

  Map<String, dynamic> toJson() {
    return {'id': id, 'savedAtMs': savedAtMs, 'search': search, 'state': state};
  }

  _SavedTarget? toSavedTarget(_HuntData data) {
    try {
      if (search['kind'] == 'static') {
        final templateJson = search['template'] as Map<String, dynamic>;
        final ivs = (state['ivs'] as List<dynamic>).cast<int>();
        final template = StaticEncounterTemplate(
          game: _gameFromJson(templateJson['game'] as String),
          type: StaticEncounterType.fromJson(templateJson['type'] as String),
          description: templateJson['description'] as String,
          species: templateJson['species'] as int,
          form: templateJson['form'] as int,
          level: templateJson['level'] as int,
          buggedRoamer: templateJson['buggedRoamer'] as bool,
        );
        final advance = state['advance'] as int;
        final seed = search['seed'] as int? ?? state['seed'] as int? ?? 0;
        final initialAdvance = search['initialAdvance'] as int? ?? advance;
        final maxAdvance = search['maxAdvance'] as int? ?? advance;
        final delay = search['delay'] as int? ?? 0;
        final method = StaticMethod.values[search['method'] as int? ?? 0];
        return _SavedStaticTarget(
          id: id,
          savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMs),
          target: _StaticTarget(
            names: data.names,
            search: _StaticSearchSnapshot(
              seed: seed,
              initialAdvance: initialAdvance,
              maxAdvance: maxAdvance,
              delay: delay,
              method: method,
              template: template,
              personalData: data.personal,
            ),
            hit: StaticSearchHit(
              template: template,
              state: StaticState(
                advance: advance,
                seed: seed,
                pid: PokemonPid(state['pid'] as int),
                ivs: Ivs(
                  hp: ivs[0],
                  attack: ivs[1],
                  defense: ivs[2],
                  specialAttack: ivs[3],
                  specialDefense: ivs[4],
                  speed: ivs[5],
                ),
                nature: Nature.values[state['nature'] as int],
                abilitySlot: state['abilitySlot'] as int,
                gender: PokemonGender.values[state['gender'] as int],
                level: state['level'] as int,
                shiny: state['shiny'] as bool,
              ),
            ),
          ),
        );
      }
      final areaJson = search['area'] as Map<String, dynamic>;
      final game = _gameFromJson(areaJson['game'] as String);
      final areaType = WildEncounterTypeJson.parse(areaJson['type'] as String);
      final area = data.wild.areas.firstWhere(
        (area) =>
            area.game == game &&
            area.locationId == areaJson['locationId'] as int &&
            area.type == areaType,
      );
      final ivRules = (search['ivRules'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (rule) => IvRule(
              value: rule['value'] as int,
              comparison: IvComparison.values[rule['comparison'] as int],
            ),
          )
          .toList(growable: false);
      final ivFilter = IvFilter(
        rules: ivRules.length == 6
            ? ivRules
            : List<IvRule>.filled(
                6,
                const IvRule(
                  value: -1,
                  comparison: IvComparison.greaterOrEqual,
                ),
              ),
      );
      final ivs = (state['ivs'] as List<dynamic>).cast<int>();
      final target = _CalibrationTarget(
        names: data.names,
        search: _HuntSearchSnapshot(
          seed: search['seed'] as int,
          initialAdvance: search['initialAdvance'] as int,
          maxAdvance: search['maxAdvance'] as int,
          delay: search['delay'] as int,
          ivFilter: ivFilter,
          shinyOnly: search['shinyOnly'] as bool,
          nature: _enumOrNull(Nature.values, search['nature']),
          hiddenPowerType: _enumOrNull(
            HiddenPowerType.values,
            search['hiddenPowerType'],
          ),
          abilitySlot: search['abilitySlot'] as int?,
          gender: _enumOrNull(PokemonGender.values, search['gender']),
          encounterSlot: search['encounterSlot'] as int?,
          synchronizeNature: _enumOrNull(
            Nature.values,
            search['synchronizeNature'],
          ),
          pressureLead: search['pressureLead'] as bool,
          staticLead: search['staticLead'] as bool,
          magnetPullLead: search['magnetPullLead'] as bool,
          cuteCharmLead: _enumOrNull(
            CuteCharmLead.values,
            search['cuteCharmLead'],
          ),
          feebasTile: search['feebasTile'] as bool,
          speciesId: search['speciesId'] as int,
          area: area,
          method: WildMethod.values[search['method'] as int],
          personalData: data.personal,
        ),
        state: WildState(
          advance: state['advance'] as int,
          pid: PokemonPid(state['pid'] as int),
          ivs: Ivs(
            hp: ivs[0],
            attack: ivs[1],
            defense: ivs[2],
            specialAttack: ivs[3],
            specialDefense: ivs[4],
            speed: ivs[5],
          ),
          nature: Nature.values[state['nature'] as int],
          abilitySlot: state['abilitySlot'] as int,
          gender: PokemonGender.values[state['gender'] as int],
          shiny: state['shiny'] as bool,
          encounterSlot: state['encounterSlot'] as int,
          species: state['species'] as int,
          form: state['form'] as int,
          level: state['level'] as int,
        ),
      );
      return _SavedCalibrationTarget(
        id: id,
        target: target,
        savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMs),
      );
    } catch (_) {
      return null;
    }
  }
}

T? _enumOrNull<T>(List<T> values, Object? index) {
  return index == null ? null : values[index as int];
}

GameVersion _gameFromJson(String value) {
  return GameVersion.values.firstWhere((game) => game.jsonName == value);
}

class _EggSettingsRecord {
  const _EggSettingsRecord({
    required this.speciesId,
    required this.method,
    required this.compatibility,
    required this.heldSeed,
    required this.pickupSeed,
    required this.heldInitial,
    required this.heldMax,
    required this.heldOffset,
    required this.pickupInitial,
    required this.pickupMax,
    required this.pickupOffset,
    required this.calibration,
    required this.minRedraws,
    required this.maxRedraws,
    required this.ivRules,
    required this.parentIvs,
    required this.parentGenders,
    required this.parentNatures,
    required this.parentItems,
    required this.shinyOnly,
    required this.nature,
    required this.hiddenPowerType,
    required this.abilitySlot,
    required this.gender,
  });

  factory _EggSettingsRecord.defaultsFor(GameVersion game) {
    final method = _defaultEggMethod(game);
    return _EggSettingsRecord(
      speciesId: null,
      method: method,
      compatibility: 70,
      heldSeed: '00000000',
      pickupSeed: '00000000',
      heldInitial: '1000',
      heldMax: '5000',
      heldOffset: '0',
      pickupInitial: '1000',
      pickupMax: '5000',
      pickupOffset: '0',
      calibration: '18',
      minRedraws: '0',
      maxRedraws: '5',
      ivRules: List<IvRule>.filled(
        6,
        const IvRule(value: -1, comparison: IvComparison.greaterOrEqual),
      ),
      parentIvs: List<Ivs>.filled(
        2,
        const Ivs(
          hp: 31,
          attack: 31,
          defense: 31,
          specialAttack: 31,
          specialDefense: 31,
          speed: 31,
        ),
      ),
      parentGenders: const [
        DaycareParentGender.male,
        DaycareParentGender.female,
      ],
      parentNatures: const [Nature.hardy, Nature.hardy],
      parentItems: const [0, 0],
      shinyOnly: false,
      nature: null,
      hiddenPowerType: null,
      abilitySlot: null,
      gender: null,
    );
  }

  factory _EggSettingsRecord.fromPage(_BreedingPageState page) {
    return _EggSettingsRecord(
      speciesId: page._speciesId,
      method: page._method,
      compatibility: page._compatibility,
      heldSeed: page._heldSeedController.text.trim(),
      pickupSeed: page._pickupSeedController.text.trim(),
      heldInitial: page._heldInitialController.text.trim(),
      heldMax: page._heldMaxController.text.trim(),
      heldOffset: page._heldOffsetController.text.trim(),
      pickupInitial: page._pickupInitialController.text.trim(),
      pickupMax: page._pickupMaxController.text.trim(),
      pickupOffset: page._pickupOffsetController.text.trim(),
      calibration: page._calibrationController.text.trim(),
      minRedraws: page._minRedrawController.text.trim(),
      maxRedraws: page._maxRedrawController.text.trim(),
      ivRules: [
        for (var i = 0; i < 6; i += 1)
          IvRule(
            value: int.tryParse(page._ivControllers[i].text.trim()) ?? -1,
            comparison: page._ivComparisons[i],
          ),
      ],
      parentIvs:
          page._parseParentIvs() ??
          _EggSettingsRecord.defaultsFor(page.widget.profile.game).parentIvs,
      parentGenders: List<DaycareParentGender>.unmodifiable(
        page._parentGenders,
      ),
      parentNatures: List<Nature>.unmodifiable(page._parentNatures),
      parentItems: List<int>.unmodifiable(page._parentItems),
      shinyOnly: page._shinyOnly,
      nature: page._nature,
      hiddenPowerType: page._hiddenPowerType,
      abilitySlot: page._abilitySlot,
      gender: page._gender,
    );
  }

  factory _EggSettingsRecord.fromJson(
    Map<String, dynamic> json,
    GameVersion game,
  ) {
    final defaults = _EggSettingsRecord.defaultsFor(game);
    try {
      final ivRules = (json['ivRules'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (rule) => IvRule(
              value: rule['value'] as int,
              comparison: IvComparison.values[rule['comparison'] as int],
            ),
          )
          .toList(growable: false);
      final parentIvs = (json['parentIvs'] as List<dynamic>? ?? const [])
          .cast<List<dynamic>>()
          .map(_ivsFromJsonList)
          .toList(growable: false);
      final parentGenders =
          (json['parentGenders'] as List<dynamic>? ?? const [])
              .cast<int>()
              .map((index) => DaycareParentGender.values[index])
              .toList(growable: false);
      final parentNatures =
          (json['parentNatures'] as List<dynamic>? ?? const [])
              .cast<int>()
              .map((index) => Nature.values[index])
              .toList(growable: false);
      final parentItems = (json['parentItems'] as List<dynamic>? ?? const [])
          .cast<int>()
          .toList(growable: false);
      final method =
          _enumOrNull(EggMethod3.values, json['method']) ?? defaults.method;

      return _EggSettingsRecord(
        speciesId: json['speciesId'] as int?,
        method: _eggMethodsForGame(game).contains(method)
            ? method
            : defaults.method,
        compatibility: json['compatibility'] as int? ?? defaults.compatibility,
        heldSeed: json['heldSeed'] as String? ?? defaults.heldSeed,
        pickupSeed: json['pickupSeed'] as String? ?? defaults.pickupSeed,
        heldInitial: json['heldInitial'] as String? ?? defaults.heldInitial,
        heldMax: json['heldMax'] as String? ?? defaults.heldMax,
        heldOffset: json['heldOffset'] as String? ?? defaults.heldOffset,
        pickupInitial:
            json['pickupInitial'] as String? ?? defaults.pickupInitial,
        pickupMax: json['pickupMax'] as String? ?? defaults.pickupMax,
        pickupOffset: json['pickupOffset'] as String? ?? defaults.pickupOffset,
        calibration: json['calibration'] as String? ?? defaults.calibration,
        minRedraws: json['minRedraws'] as String? ?? defaults.minRedraws,
        maxRedraws: json['maxRedraws'] as String? ?? defaults.maxRedraws,
        ivRules: ivRules.length == 6 ? ivRules : defaults.ivRules,
        parentIvs: parentIvs.length == 2 ? parentIvs : defaults.parentIvs,
        parentGenders: parentGenders.length == 2
            ? parentGenders
            : defaults.parentGenders,
        parentNatures: parentNatures.length == 2
            ? parentNatures
            : defaults.parentNatures,
        parentItems: parentItems.length == 2
            ? parentItems
            : defaults.parentItems,
        shinyOnly: json['shinyOnly'] as bool? ?? defaults.shinyOnly,
        nature: _enumOrNull(Nature.values, json['nature']),
        hiddenPowerType: _enumOrNull(
          HiddenPowerType.values,
          json['hiddenPowerType'],
        ),
        abilitySlot: json['abilitySlot'] as int?,
        gender: _enumOrNull(PokemonGender.values, json['gender']),
      );
    } catch (_) {
      return defaults;
    }
  }

  final int? speciesId;
  final EggMethod3 method;
  final int compatibility;
  final String heldSeed;
  final String pickupSeed;
  final String heldInitial;
  final String heldMax;
  final String heldOffset;
  final String pickupInitial;
  final String pickupMax;
  final String pickupOffset;
  final String calibration;
  final String minRedraws;
  final String maxRedraws;
  final List<IvRule> ivRules;
  final List<Ivs> parentIvs;
  final List<DaycareParentGender> parentGenders;
  final List<Nature> parentNatures;
  final List<int> parentItems;
  final bool shinyOnly;
  final Nature? nature;
  final HiddenPowerType? hiddenPowerType;
  final int? abilitySlot;
  final PokemonGender? gender;

  Map<String, dynamic> toJson() {
    return {
      'speciesId': speciesId,
      'method': method.index,
      'compatibility': compatibility,
      'heldSeed': heldSeed,
      'pickupSeed': pickupSeed,
      'heldInitial': heldInitial,
      'heldMax': heldMax,
      'heldOffset': heldOffset,
      'pickupInitial': pickupInitial,
      'pickupMax': pickupMax,
      'pickupOffset': pickupOffset,
      'calibration': calibration,
      'minRedraws': minRedraws,
      'maxRedraws': maxRedraws,
      'ivRules': [
        for (final rule in ivRules)
          {'value': rule.value, 'comparison': rule.comparison.index},
      ],
      'parentIvs': [for (final ivs in parentIvs) ivs.ordered],
      'parentGenders': [for (final gender in parentGenders) gender.index],
      'parentNatures': [for (final nature in parentNatures) nature.index],
      'parentItems': parentItems,
      'shinyOnly': shinyOnly,
      'nature': nature?.index,
      'hiddenPowerType': hiddenPowerType?.index,
      'abilitySlot': abilitySlot,
      'gender': gender?.index,
    };
  }

  static Ivs _ivsFromJsonList(List<dynamic> values) {
    final ivs = values.cast<int>();
    return Ivs(
      hp: ivs[0],
      attack: ivs[1],
      defense: ivs[2],
      specialAttack: ivs[3],
      specialDefense: ivs[4],
      speed: ivs[5],
    );
  }
}

class _AppStorage {
  _AppStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<Map<GameVersion, AppProfile>> loadProfiles() async {
    final profiles = <GameVersion, AppProfile>{};
    for (final game in GameVersion.values) {
      profiles[game] = await loadProfile(game);
    }
    return profiles;
  }

  Future<AppProfile> loadProfile(GameVersion game) async {
    final tid = await _preferences.getInt(_profileKey(game, 'tid')) ?? 0;
    final sid = await _preferences.getInt(_profileKey(game, 'sid')) ?? 0;
    final seed =
        await _preferences.getString(_profileKey(game, 'seed')) ??
        game.defaultSeed;
    return AppProfile(game: game, tid: tid, sid: sid, defaultSeed: seed);
  }

  Future<void> saveProfile(AppProfile profile) async {
    await _preferences.setInt(_profileKey(profile.game, 'tid'), profile.tid);
    await _preferences.setInt(_profileKey(profile.game, 'sid'), profile.sid);
    await _preferences.setString(
      _profileKey(profile.game, 'seed'),
      profile.defaultSeed,
    );
  }

  Future<GameVersion> loadCurrentGame() async {
    final raw = await _preferences.getString('app.currentGame');
    if (raw == null) {
      return GameVersion.emerald;
    }
    return GameVersion.values.firstWhere(
      (game) => game.jsonName == raw,
      orElse: () => GameVersion.emerald,
    );
  }

  Future<void> saveCurrentGame(GameVersion game) async {
    await _preferences.setString('app.currentGame', game.jsonName);
  }

  Future<_AppLanguage> loadLanguage() async {
    final raw = await _preferences.getString('app.language');
    if (raw == null) {
      return _AppLanguage.system;
    }
    return _AppLanguage.values.firstWhere(
      (language) => language.jsonName == raw,
      orElse: () => _AppLanguage.system,
    );
  }

  Future<void> saveLanguage(_AppLanguage language) async {
    await _preferences.setString('app.language', language.jsonName);
  }

  Future<List<_SavedTargetRecord>> loadTargets(GameVersion game) async {
    final raw = await _preferences.getString(_targetsKey(game));
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final json = jsonDecode(raw) as List<dynamic>;
      return json
          .cast<Map<String, dynamic>>()
          .map(_SavedTargetRecord.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTargets(GameVersion game, List<_SavedTarget> targets) async {
    final json = targets
        .take(_maxSavedTargets)
        .map((target) => _SavedTargetRecord.fromSaved(target).toJson())
        .toList(growable: false);
    await _preferences.setString(_targetsKey(game), jsonEncode(json));
  }

  Future<_EggSettingsRecord> loadEggSettings(GameVersion game) async {
    final raw = await _preferences.getString(_eggSettingsKey(game));
    if (raw == null || raw.isEmpty) {
      return _EggSettingsRecord.defaultsFor(game);
    }
    try {
      return _EggSettingsRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        game,
      );
    } catch (_) {
      return _EggSettingsRecord.defaultsFor(game);
    }
  }

  Future<void> saveEggSettings(
    GameVersion game,
    _EggSettingsRecord settings,
  ) async {
    await _preferences.setString(
      _eggSettingsKey(game),
      jsonEncode(settings.toJson()),
    );
  }

  String _profileKey(GameVersion game, String field) {
    return 'profile.${game.jsonName}.$field';
  }

  String _targetsKey(GameVersion game) {
    return 'targets.${game.jsonName}';
  }

  String _eggSettingsKey(GameVersion game) {
    return 'eggSettings.${game.jsonName}';
  }
}

sealed class _HuntResult {
  const _HuntResult();

  factory _HuntResult.wild(WildState state) = _WildHuntResult;

  factory _HuntResult.static(StaticSearchHit hit) = _StaticHuntResult;
}

class _WildHuntResult extends _HuntResult {
  const _WildHuntResult(this.state);

  final WildState state;
}

class _StaticHuntResult extends _HuntResult {
  const _StaticHuntResult(this.hit);

  final StaticSearchHit hit;
}

class _HuntResultsSnapshot {
  const _HuntResultsSnapshot({
    this.error,
    this.names,
    this.search,
    this.staticSearch,
    this.delay = 0,
    this.results = const <_HuntResult>[],
    this.resultLimitReached = false,
    this.searching = false,
    this.searchProgress,
  });

  final String? error;
  final Gen3NamedResources? names;
  final _HuntSearchSnapshot? search;
  final _StaticSearchSnapshot? staticSearch;
  final int delay;
  final List<_HuntResult> results;
  final bool resultLimitReached;
  final bool searching;
  final double? searchProgress;
}

class _ParsedHuntInputs {
  const _ParsedHuntInputs({
    required this.seed,
    required this.initialAdvance,
    required this.maxAdvance,
    required this.delay,
    required this.ivFilter,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvance;
  final int delay;
  final IvFilter ivFilter;
}

class _SpeciesOption {
  const _SpeciesOption({
    required this.speciesId,
    required this.name,
    required this.displayName,
    required this.numberText,
    required this.searchText,
  });

  final int speciesId;
  final String name;
  final String displayName;
  final String numberText;
  final String searchText;
}

class _HuntData {
  const _HuntData({
    required this.localeName,
    required this.names,
    required this.locations,
    required this.personal,
    required this.wild,
    required this.staticEncounters,
    required this.speciesOptions,
  });

  final String localeName;
  final Gen3NamedResources names;
  final Gen3LocationNames locations;
  final Gen3PersonalData personal;
  final Gen3WildEncounterRepository wild;
  final Gen3StaticEncounterRepository staticEncounters;
  final List<_SpeciesOption> speciesOptions;

  static Future<_HuntData> load(String localeName) async {
    final values = await Future.wait([
      Gen3NamedResources.load(localeName),
      Gen3LocationNames.load(localeName),
      Gen3PersonalData.load(),
      Gen3WildEncounterRepository.load(),
      Gen3StaticEncounterRepository.load(),
    ]);
    final names = values[0] as Gen3NamedResources;
    final speciesOptions = List<_SpeciesOption>.generate(386, (index) {
      final speciesId = index + 1;
      final numberText = speciesId.toString();
      final paddedNumber = numberText.padLeft(3, '0');
      final name = names.speciesName(speciesId);
      return _SpeciesOption(
        speciesId: speciesId,
        name: name,
        displayName: '$paddedNumber $name',
        numberText: numberText,
        searchText: names.speciesSearchText(speciesId),
      );
    }, growable: false);

    return _HuntData(
      localeName: localeName,
      names: names,
      locations: values[1] as Gen3LocationNames,
      personal: values[2] as Gen3PersonalData,
      wild: values[3] as Gen3WildEncounterRepository,
      staticEncounters: values[4] as Gen3StaticEncounterRepository,
      speciesOptions: speciesOptions,
    );
  }

  List<WildEncounterArea> areasForSpecies({
    required GameVersion game,
    required int speciesId,
  }) {
    return wild.areasForSpecies(game: game, speciesId: speciesId);
  }

  List<StaticEncounterTemplate> staticTemplatesForSpecies({
    required GameVersion game,
    required int speciesId,
  }) {
    return staticEncounters.templatesForSpecies(
      game: game,
      speciesId: speciesId,
    );
  }

  List<WildEncounterType> encounterTypesForSpecies({
    required GameVersion game,
    required int speciesId,
  }) {
    final seen = <WildEncounterType>{};
    final result = <WildEncounterType>[];
    for (final area in areasForSpecies(game: game, speciesId: speciesId)) {
      if (seen.add(area.type)) {
        result.add(area.type);
      }
    }
    return result;
  }

  String locationLabel(BuildContext context, WildEncounterArea area) {
    final location = locations.name(
      game: area.game,
      locationId: area.locationId,
      fallback: area.label,
    );
    return location;
  }

  String staticTemplateLabel(
    BuildContext context,
    StaticEncounterTemplate template,
  ) {
    return '${_staticEncounterTypeLabel(context, template.type)} · '
        '${_staticTemplateDescription(template)} · ${AppLocalizations.of(context)!.levelShort} ${template.level}';
  }

  String _staticTemplateDescription(StaticEncounterTemplate template) {
    final separator = template.description.indexOf(' @ ');
    final speciesName = names.speciesName(template.species);
    if (separator < 0) {
      if (template.description.endsWith(' Egg')) {
        return '$speciesName Egg';
      }
      return speciesName;
    }
    final locationName = template.description.substring(separator + 3);
    return '$speciesName @ ${locations.staticLocationName(locationName)}';
  }

  String natureLabel(BuildContext context, Nature nature) {
    return '${names.natureName(nature)} · ${_natureEffectLabel(context, nature)}';
  }

  String speciesDisplayName(int speciesId) {
    return speciesOptions
        .firstWhere((option) => option.speciesId == speciesId)
        .displayName;
  }
}

int? _numericSpeciesStart(String query) {
  if (!RegExp(r'^\d+$').hasMatch(query)) {
    return null;
  }
  final normalized = query.replaceFirst(RegExp(r'^0+'), '');
  final value = int.tryParse(normalized.isEmpty ? '0' : normalized);
  if (value == null || value <= 0) {
    return 1;
  }
  return value;
}

String _encounterTypeLabel(BuildContext context, WildEncounterType type) {
  final l10n = AppLocalizations.of(context)!;
  return switch (type) {
    WildEncounterType.grass => l10n.encounterGrass,
    WildEncounterType.surfing => l10n.encounterSurfing,
    WildEncounterType.rockSmash => l10n.encounterRockSmash,
    WildEncounterType.oldRod => l10n.encounterOldRod,
    WildEncounterType.goodRod => l10n.encounterGoodRod,
    WildEncounterType.superRod => l10n.encounterSuperRod,
  };
}

String _staticEncounterTypeLabel(
  BuildContext context,
  StaticEncounterType type,
) {
  final l10n = AppLocalizations.of(context)!;
  return switch (type) {
    StaticEncounterType.starter => l10n.staticStarter,
    StaticEncounterType.fossil => l10n.staticFossil,
    StaticEncounterType.gift => l10n.staticGift,
    StaticEncounterType.gameCorner => l10n.staticGameCorner,
    StaticEncounterType.stationary => l10n.staticStationary,
    StaticEncounterType.legend => l10n.staticLegend,
    StaticEncounterType.event => l10n.staticEvent,
    StaticEncounterType.roamer => l10n.staticRoamer,
  };
}

StaticMethod _staticMethodFor(WildMethod method) {
  return switch (method) {
    WildMethod.method1 => StaticMethod.method1,
    WildMethod.method2 => StaticMethod.method2,
    WildMethod.method4 => StaticMethod.method4,
  };
}

String _wildMethodLabel(BuildContext context, WildMethod method) {
  final l10n = AppLocalizations.of(context)!;
  return switch (method) {
    WildMethod.method1 => l10n.wildMethod1,
    WildMethod.method2 => l10n.wildMethod2,
    WildMethod.method4 => l10n.wildMethod4,
  };
}

WildMethod _defaultWildMethodForGame(GameVersion game) {
  return switch (game) {
    GameVersion.emerald => WildMethod.method2,
    GameVersion.fireRed || GameVersion.leafGreen => WildMethod.method1,
  };
}

List<WildMethod> _wildReverseMethods(WildMethod selected) {
  return [
    selected,
    for (final method in WildMethod.values)
      if (method != selected) method,
  ];
}

List<EggMethod3> _eggMethodsForGame(GameVersion game) {
  return switch (game) {
    GameVersion.emerald => const [
      EggMethod3.emeraldBred,
      EggMethod3.emeraldBredSplit,
      EggMethod3.emeraldBredAlternate,
    ],
    GameVersion.fireRed || GameVersion.leafGreen => const [
      EggMethod3.rsFrLgBred,
      EggMethod3.rsFrLgBredSplit,
      EggMethod3.rsFrLgBredAlternate,
      EggMethod3.rsFrLgBredMixed,
    ],
  };
}

EggMethod3 _defaultEggMethod(GameVersion game) =>
    _eggMethodsForGame(game).first;

String _eggMethodLabel(EggMethod3 method) {
  return switch (method) {
    EggMethod3.emeraldBred => 'EBred',
    EggMethod3.emeraldBredSplit => 'EBred Split',
    EggMethod3.emeraldBredAlternate => 'EBred Alternate',
    EggMethod3.rsFrLgBred => 'RS/FRLG Bred',
    EggMethod3.rsFrLgBredSplit => 'RS/FRLG Bred Split',
    EggMethod3.rsFrLgBredAlternate => 'RS/FRLG Bred Alternate',
    EggMethod3.rsFrLgBredMixed => 'RS/FRLG Bred Mixed',
  };
}

String _parentGenderLabel(BuildContext context, DaycareParentGender gender) {
  final l10n = AppLocalizations.of(context)!;
  return switch (gender) {
    DaycareParentGender.male => '♂',
    DaycareParentGender.female => '♀',
    DaycareParentGender.genderless => '-',
    DaycareParentGender.ditto => l10n.ditto,
  };
}

String _eggInheritanceSummary(BuildContext context, List<int> inheritance) {
  final l10n = AppLocalizations.of(context)!;
  return [
    for (var i = 0; i < inheritance.length; i += 1)
      '${_shortIvLabel(i)}:${_eggInheritanceSourceLabel(l10n, inheritance[i])}',
  ].join(' ');
}

String _eggInheritanceSourceLabel(AppLocalizations l10n, int source) {
  return switch (source) {
    1 => l10n.parentAShort,
    2 => l10n.parentBShort,
    _ => l10n.inheritRandom,
  };
}

String _shortIvLabel(int index) {
  return const ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'][index];
}

String _formatInteger(BigInt value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String _formatDuration(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final hours = clamped.inHours;
  final minutes = clamped.inMinutes.remainder(60);
  final seconds = clamped.inSeconds.remainder(60);
  final milliseconds = clamped.inMilliseconds.remainder(1000);
  final secondText = seconds.toString().padLeft(2, '0');
  final millisecondText = milliseconds.toString().padLeft(3, '0');
  if (hours > 0) {
    final minuteText = minutes.toString().padLeft(2, '0');
    return '$hours:$minuteText:$secondText.$millisecondText';
  }
  return '$minutes:$secondText.$millisecondText';
}

int? _parseHexInput(String value) {
  final normalized = value.trim().replaceFirst(RegExp('^0x'), '');
  if (normalized.isEmpty || normalized.length > 8) {
    return null;
  }
  return int.tryParse(normalized, radix: 16);
}

String _abilitySlotLabel({
  required BuildContext context,
  required int slot,
  required String name,
}) {
  return AppLocalizations.of(context)!.abilitySlot(slot + 1, name);
}

String _calibrationNatureLabel(
  Nature nature, {
  required Gen3NamedResources? primaryNames,
  required Gen3NamedResources? secondaryNames,
}) {
  return _pairedName(
    primaryNames?.natureName(nature) ?? nature.name,
    secondaryNames?.natureName(nature),
  );
}

String _pairedName(String primary, String? secondary) {
  if (secondary == null || secondary == primary) {
    return primary;
  }
  return '$primary / $secondary';
}

List<int> _slotsForSpecies(WildEncounterArea area, int speciesId) {
  final result = <int>[];
  for (var i = 0; i < area.slots.length; i += 1) {
    if (area.slots[i].species == speciesId) {
      result.add(i);
    }
  }
  return result;
}

List<PokemonGender> _legalGenders(Gen3PersonalInfo? info) {
  return switch (info?.genderRatio) {
    null => const [],
    255 => const [PokemonGender.genderless],
    254 => const [PokemonGender.female],
    0 => const [PokemonGender.male],
    _ => const [PokemonGender.male, PokemonGender.female],
  };
}

List<_LeadMode> _availableLeadModes({
  required WildEncounterArea? area,
  required Gen3PersonalData personalData,
  required Gen3PersonalInfo? targetPersonal,
}) {
  final result = <_LeadMode>[
    _LeadMode.none,
    _LeadMode.pressure,
    _LeadMode.synchronize,
  ];
  if (area != null) {
    if (_hasSelectiveTypeLead(
      area: area,
      personalData: personalData,
      typeId: 12,
    )) {
      result.add(_LeadMode.staticLead);
    }
    if (_hasSelectiveTypeLead(
      area: area,
      personalData: personalData,
      typeId: 8,
    )) {
      result.add(_LeadMode.magnetPull);
    }
  }
  if (_canUseCuteCharm(targetPersonal)) {
    result
      ..add(_LeadMode.cuteCharmFemale)
      ..add(_LeadMode.cuteCharmMale);
  }
  return result;
}

_LeadMode _effectiveLeadMode({
  required _LeadMode leadMode,
  required WildEncounterArea area,
  required Gen3PersonalData personalData,
  required Gen3PersonalInfo? targetPersonal,
}) {
  final available = _availableLeadModes(
    area: area,
    personalData: personalData,
    targetPersonal: targetPersonal,
  );
  return available.contains(leadMode) ? leadMode : _LeadMode.none;
}

bool _hasSelectiveTypeLead({
  required WildEncounterArea area,
  required Gen3PersonalData personalData,
  required int typeId,
}) {
  var matchingSlots = 0;
  for (final slot in area.slots) {
    final info = personalData[slot.species];
    if (info != null && info.typeIds.contains(typeId)) {
      matchingSlots += 1;
    }
  }
  return matchingSlots > 0 && matchingSlots < area.slots.length;
}

bool _canUseCuteCharm(Gen3PersonalInfo? info) {
  final genderRatio = info?.genderRatio;
  return genderRatio != null &&
      genderRatio != 0 &&
      genderRatio != 254 &&
      genderRatio != 255;
}

String _leadModeLabel(BuildContext context, _LeadMode mode) {
  final l10n = AppLocalizations.of(context)!;
  return switch (mode) {
    _LeadMode.none => l10n.leadNone,
    _LeadMode.pressure => l10n.leadPressure,
    _LeadMode.synchronize => l10n.leadSynchronize,
    _LeadMode.staticLead => l10n.leadStatic,
    _LeadMode.magnetPull => l10n.leadMagnetPull,
    _LeadMode.cuteCharmFemale => l10n.leadCuteCharmFemale,
    _LeadMode.cuteCharmMale => l10n.leadCuteCharmMale,
  };
}

String _genderLabel(PokemonGender gender) {
  return switch (gender) {
    PokemonGender.male => '♂',
    PokemonGender.female => '♀',
    PokemonGender.genderless => '-',
  };
}

bool _isFeebasArea(WildEncounterArea area) {
  return area.game == GameVersion.emerald &&
      area.locationId == 33 &&
      (area.type == WildEncounterType.oldRod ||
          area.type == WildEncounterType.goodRod ||
          area.type == WildEncounterType.superRod);
}

CuteCharmLead? _cuteCharmLead(_LeadMode leadMode) {
  return switch (leadMode) {
    _LeadMode.cuteCharmFemale => CuteCharmLead.female,
    _LeadMode.cuteCharmMale => CuteCharmLead.male,
    _ => null,
  };
}

String _natureEffectLabel(BuildContext context, Nature nature) {
  final plus = nature.index ~/ 5;
  final minus = nature.index % 5;
  final l10n = AppLocalizations.of(context)!;
  final statNames = [
    l10n.statAttack,
    l10n.statDefense,
    l10n.statSpeed,
    l10n.statSpecialAttack,
    l10n.statSpecialDefense,
  ];
  if (plus == minus) {
    return l10n.natureNeutral;
  }
  return '+${statNames[plus]} -${statNames[minus]}';
}

String _hiddenPowerTypeLabel(BuildContext context, HiddenPowerType type) {
  final l10n = AppLocalizations.of(context)!;
  return switch (type) {
    HiddenPowerType.fighting => l10n.typeFighting,
    HiddenPowerType.flying => l10n.typeFlying,
    HiddenPowerType.poison => l10n.typePoison,
    HiddenPowerType.ground => l10n.typeGround,
    HiddenPowerType.rock => l10n.typeRock,
    HiddenPowerType.bug => l10n.typeBug,
    HiddenPowerType.ghost => l10n.typeGhost,
    HiddenPowerType.steel => l10n.typeSteel,
    HiddenPowerType.fire => l10n.typeFire,
    HiddenPowerType.water => l10n.typeWater,
    HiddenPowerType.grass => l10n.typeGrass,
    HiddenPowerType.electric => l10n.typeElectric,
    HiddenPowerType.psychic => l10n.typePsychic,
    HiddenPowerType.ice => l10n.typeIce,
    HiddenPowerType.dragon => l10n.typeDragon,
    HiddenPowerType.dark => l10n.typeDark,
  };
}
