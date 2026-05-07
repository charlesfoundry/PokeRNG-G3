import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

const _eggEncounterKey = 'egg';
const _maxSearchAdvanceDelta = 10000000;
const _maxDisplayedResults = 500;
const _maxSpeciesSuggestions = 50;
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
  AppProfile _profile = AppProfile.initial();

  void _setProfile(AppProfile profile) {
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
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
      home: AppShell(profile: _profile, onProfileChanged: _setProfile),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  final AppProfile profile;
  final ValueChanged<AppProfile> onProfileChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _huntKey = GlobalKey<_HuntPageState>();
  int _selectedIndex = 0;
  _HuntSearchSnapshot? _huntSearch;
  _CalibrationTarget? _calibrationTarget;
  final List<_SavedCalibrationTarget> _savedTargets = [];
  _HuntResultsSnapshot _huntResults = const _HuntResultsSnapshot();

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.game != widget.profile.game) {
      _huntSearch = null;
      _calibrationTarget = null;
      _huntResults = const _HuntResultsSnapshot();
    }
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
          setState(() {
            _savedTargets.insert(
              0,
              _SavedCalibrationTarget(
                id: DateTime.now().microsecondsSinceEpoch,
                target: target,
                savedAt: DateTime.now(),
              ),
            );
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.targetSaved)));
        },
      ),
      _CalibratePage(
        profile: widget.profile,
        search: _huntSearch,
        target: _calibrationTarget,
      ),
      _ToolsPage(
        savedTargets: _savedTargets,
        onUseTarget: (saved) {
          setState(() {
            _huntSearch = saved.target.search;
            _calibrationTarget = saved.target;
            _selectedIndex = 2;
          });
        },
        onDeleteTarget: (saved) {
          setState(() {
            _savedTargets.removeWhere((target) => target.id == saved.id);
          });
        },
      ),
      SettingsPage(
        profile: widget.profile,
        onProfileChanged: widget.onProfileChanged,
      ),
    ];
    final pageStack = IndexedStack(index: _selectedIndex, children: pages);

    return Scaffold(
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
                  icon: const Icon(Icons.build),
                  label: l10n.tools,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings),
                  label: l10n.settings,
                ),
              ],
            ),
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
  final _hpIvController = TextEditingController(text: '-1');
  final _attackIvController = TextEditingController(text: '-1');
  final _defenseIvController = TextEditingController(text: '-1');
  final _specialAttackIvController = TextEditingController(text: '-1');
  final _specialDefenseIvController = TextEditingController(text: '-1');
  final _speedIvController = TextEditingController(text: '-1');

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = Localizations.localeOf(context).toString();
    if (_localeName != localeName) {
      _localeName = localeName;
      _dataFuture = _HuntData.load(localeName);
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
      _wildMethod = WildMethod.method1;
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
    setState(() {
      _selectedSpeciesId = speciesId;
      _pokemonController.text = data.speciesDisplayName(speciesId);
      _encounterType = nextType;
      _locationKey = nextAreas.isNotEmpty
          ? _areaKey(nextAreas.first)
          : staticTemplates.isNotEmpty
          ? _staticTemplateKey(staticTemplates.first)
          : null;
      _abilitySlot = null;
      _gender = null;
      _encounterSlot = null;
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
      _leadMode = _LeadMode.none;
    });
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

    setState(() {
      _error = null;
    });
    final epoch = _searchEpoch + 1;
    _searchEpoch = epoch;
    setState(() => _searching = true);
    widget.onResultsChanged(
      _HuntResultsSnapshot(
        names: data.names,
        searching: true,
        delay: parsed.delay,
        searchProgress: 0,
      ),
    );

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
    if (speciesId == null ||
        locationKey == null ||
        locationKey == _eggEncounterKey) {
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
    if (speciesId == null ||
        locationKey == null ||
        locationKey == _eggEncounterKey) {
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
      int.tryParse(_hpIvController.text.trim()),
      int.tryParse(_attackIvController.text.trim()),
      int.tryParse(_defenseIvController.text.trim()),
      int.tryParse(_specialAttackIvController.text.trim()),
      int.tryParse(_specialDefenseIvController.text.trim()),
      int.tryParse(_speedIvController.text.trim()),
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
        locationKey == null ||
            locationKey == _eggEncounterKey ||
            !locationKeys.contains(locationKey)
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
        RawAutocomplete<_SpeciesOption>(
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
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
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
              DropdownMenuItem<String?>(
                value: _eggEncounterKey,
                enabled: false,
                child: Text(
                  l10n.eggUnsupported,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
                Text(
                  l10n.eggUnsupported,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
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
    required this.delay,
    required this.results,
    required this.resultLimitReached,
    required this.searching,
    required this.searchProgress,
    required this.onCancelSearch,
    required this.onSendToCalibration,
    required this.onSaveTarget,
  });

  final String? error;
  final Gen3NamedResources names;
  final _HuntSearchSnapshot? search;
  final int delay;
  final List<_HuntResult> results;
  final bool resultLimitReached;
  final bool searching;
  final double? searchProgress;
  final VoidCallback onCancelSearch;
  final ValueChanged<_CalibrationTarget> onSendToCalibration;
  final ValueChanged<_CalibrationTarget> onSaveTarget;

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
                        ),
                      ),
                      _StaticHuntResult(:final hit) => _StaticResultTile(
                        hit: hit,
                        triggerAdvance: hit.state.advance - delay,
                        natureName: names.natureName(hit.state.nature),
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
  });

  final _HuntResultsSnapshot snapshot;
  final VoidCallback onCancelSearch;
  final ValueChanged<_CalibrationTarget> onSendToCalibration;
  final ValueChanged<_CalibrationTarget> onSaveTarget;

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
      delay: snapshot.delay,
      results: snapshot.results,
      resultLimitReached: snapshot.resultLimitReached,
      searching: snapshot.searching,
      searchProgress: snapshot.searchProgress,
      onCancelSearch: onCancelSearch,
      onSendToCalibration: onSendToCalibration,
      onSaveTarget: onSaveTarget,
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
  });

  final WildState state;
  final int triggerAdvance;
  final String natureName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hiddenPower = state.ivs.hiddenPower;
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
                  child: _ResultField(
                    label: l10n.levelShort,
                    value: '${state.level}',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _ResultField(
                    label: 'PID',
                    value: state.pid.toString(),
                  ),
                ),
                if (state.shiny) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.shiny),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
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
  });

  final StaticSearchHit hit;
  final int triggerAdvance;
  final String natureName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = hit.state;
    final hiddenPower = state.ivs.hiddenPower;
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
                  child: _ResultField(
                    label: l10n.levelShort,
                    value: '${state.level}',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _ResultField(
                    label: 'PID',
                    value: state.pid.toString(),
                  ),
                ),
                if (state.shiny) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.shiny),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
  });

  final AppProfile profile;
  final _HuntSearchSnapshot? search;
  final _CalibrationTarget? target;

  @override
  State<_CalibratePage> createState() => _CalibratePageState();
}

class _CalibratePageState extends State<_CalibratePage> {
  final _targetAdvanceController = TextEditingController();
  final _actualAdvanceController = TextEditingController();
  final _outputController = TextEditingController();
  final _targetDeltaController = TextEditingController();
  final _statControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  int? _observedSpeciesId;
  Nature? _observedNature;
  int? _observedAbilitySlot;
  PokemonGender? _observedGender;
  List<WildCalibrationHit> _hits = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncTarget(widget.target);
  }

  @override
  void didUpdateWidget(covariant _CalibratePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _syncTarget(widget.target);
    }
  }

  @override
  void dispose() {
    _targetAdvanceController.dispose();
    _actualAdvanceController.dispose();
    _outputController.dispose();
    _targetDeltaController.dispose();
    for (final controller in _statControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncTarget(_CalibrationTarget? target) {
    if (target == null) {
      return;
    }
    _targetAdvanceController.text =
        '${target.state.advance - target.search.delay}';
    _actualAdvanceController.clear();
    _outputController.clear();
    _targetDeltaController.clear();
    _observedSpeciesId = target.state.species;
    _observedNature = null;
    _observedAbilitySlot = null;
    _observedGender = null;
    _hits = const [];
    _error = null;
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

    final referenceAdvance = widget.target?.state.advance ?? currentPress;
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
    });
  }

  void _reverseHit() {
    final search = widget.target?.search ?? widget.search;
    final observedStats = _parseStats();

    if (search == null || observedStats == null) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.runHuntAndEnterObservedStatsError;
        _hits = const [];
      });
      return;
    }

    final observedSpeciesId = _observedSpeciesId ?? search.speciesId;
    final request = WildCalibrationRequest(
      seed: search.seed,
      initialAdvance: search.initialAdvance,
      maxAdvance: search.maxAdvance,
      delay: search.delay,
      method: search.method,
      area: search.area,
      tid: widget.profile.tid,
      sid: widget.profile.sid,
      speciesId: observedSpeciesId,
      observedStats: observedStats,
      observedNature: _observedNature,
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
    final hits = request.findMatches(limit: 50);

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
    Gen3NamedResources? names,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      DropdownMenuItem<int?>(value: null, child: Text(l10n.any)),
      if (personal != null)
        ...List<DropdownMenuItem<int?>>.generate(2, (slot) {
          final id = personal.abilityIds[slot];
          return DropdownMenuItem<int?>(
            value: slot,
            child: Text(
              _abilitySlotLabel(
                context: context,
                slot: slot,
                name: names?.abilityName(id) ?? 'Ability $id',
              ),
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
        child: TextField(
          controller: _statControllers[index],
          decoration: InputDecoration(
            labelText: labels[index],
            border: _controlBorder,
          ),
          keyboardType: TextInputType.number,
        ),
      );
    }, growable: false);
  }

  void _selectHit(WildCalibrationHit hit) {
    _actualAdvanceController.text = '${hit.state.advance}';
    _outputController.text = AppLocalizations.of(
      context,
    )!.actualAdvanceOutput(hit.state.advance);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = widget.target;
    final search = target?.search ?? widget.search;
    final observedSpeciesId = _observedSpeciesId ?? search?.speciesId;
    final personal = observedSpeciesId == null
        ? null
        : search?.personalData[observedSpeciesId];
    final names = target?.names;
    final theme = Theme.of(context);

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
        const SizedBox(height: 20),
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
          items: _speciesItems(search, names),
          onChanged: search == null
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
        DropdownButtonFormField<int?>(
          key: ValueKey(
            'calibration-ability-$observedSpeciesId-$_observedAbilitySlot',
          ),
          isExpanded: true,
          initialValue: _observedAbilitySlot,
          decoration: InputDecoration(
            labelText: l10n.ability,
            border: _controlBorder,
          ),
          items: _abilityItems(context, personal, names),
          onChanged: personal == null
              ? null
              : (value) => setState(() => _observedAbilitySlot = value),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<Nature?>(
                isExpanded: true,
                initialValue: _observedNature,
                decoration: InputDecoration(
                  labelText: l10n.nature,
                  border: _controlBorder,
                ),
                items: [
                  DropdownMenuItem<Nature?>(value: null, child: Text(l10n.any)),
                  ...Nature.values.map(
                    (nature) => DropdownMenuItem<Nature?>(
                      value: nature,
                      child: Text(
                        names?.natureName(nature) ?? nature.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _observedNature = value),
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
              triggerAdvance: hit.state.advance - (search?.delay ?? 0),
              speciesName:
                  names?.speciesName(hit.state.species) ??
                  '#${hit.state.species}',
              natureName:
                  names?.natureName(hit.state.nature) ?? hit.state.nature.name,
              onTap: () => _selectHit(hit),
            ),
          ),
        ],
      ],
    );
  }
}

class _CalibrationTargetCard extends StatelessWidget {
  const _CalibrationTargetCard({required this.target});

  final _CalibrationTarget? target;

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

    final state = target.state;
    final species = target.names.speciesName(state.species);
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
                Expanded(child: Text('#${state.species} $species')),
                Text('${l10n.resultAdvance} ${state.advance}'),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.levelShort} ${state.level} · '
                    '${_genderLabel(state.gender)} · '
                    '${target.names.natureName(state.nature)}',
                  ),
                ),
                Text('PID ${state.pid}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationHitTile extends StatelessWidget {
  const _CalibrationHitTile({
    required this.hit,
    required this.triggerAdvance,
    required this.speciesName,
    required this.natureName,
    required this.onTap,
  });

  final WildCalibrationHit hit;
  final int triggerAdvance;
  final String speciesName;
  final String natureName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = hit.state;
    final stats = hit.stats;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _HoverSurface(
        child: ListTile(
          dense: true,
          onTap: onTap,
          title: Text(
            '#${state.species} $speciesName · '
            '${l10n.resultAdvance} ${state.advance} · '
            '${l10n.resultPress} $triggerAdvance · '
            '${l10n.levelShort} ${state.level}',
          ),
          subtitle: Text(
            '$natureName · ${_genderLabel(state.gender)} · '
            '${stats ?? state.ivs}',
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _ToolsPage extends StatelessWidget {
  const _ToolsPage({
    required this.savedTargets,
    required this.onUseTarget,
    required this.onDeleteTarget,
  });

  final List<_SavedCalibrationTarget> savedTargets;
  final ValueChanged<_SavedCalibrationTarget> onUseTarget;
  final ValueChanged<_SavedCalibrationTarget> onDeleteTarget;

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
        _ToolTile(icon: Icons.badge, title: l10n.idSid),
        _ToolTile(icon: Icons.science, title: l10n.ivsToPid),
        _ToolTile(icon: Icons.video_collection, title: l10n.battleVideo),
        _ToolTile(icon: Icons.image_search, title: l10n.painting),
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

  final _SavedCalibrationTarget saved;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = saved.target;
    final state = target.state;
    final hiddenPower = state.ivs.hiddenPower;
    return _HoverSurface(
      child: ListTile(
        dense: true,
        onTap: onUse,
        title: Text(
          '#${state.species} ${target.names.speciesName(state.species)} · '
          '${l10n.resultAdvance} ${state.advance}',
        ),
        subtitle: Text(
          '${l10n.levelShort} ${state.level} · '
          '${_genderLabel(state.gender)} · '
          '${target.names.natureName(state.nature)} · '
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

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      enabled: false,
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  final AppProfile profile;
  final ValueChanged<AppProfile> onProfileChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _tidController;
  late final TextEditingController _sidController;
  late final TextEditingController _seedController;
  late GameVersion _game;
  String? _error;

  @override
  void initState() {
    super.initState();
    _game = widget.profile.game;
    _tidController = TextEditingController(text: '${widget.profile.tid}');
    _sidController = TextEditingController(text: '${widget.profile.sid}');
    _seedController = TextEditingController(text: widget.profile.defaultSeed);
  }

  @override
  void dispose() {
    _tidController.dispose();
    _sidController.dispose();
    _seedController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
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
              _seedController.text = _game.defaultSeed;
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
      ],
    );
  }
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

class _CalibrationTarget {
  const _CalibrationTarget({
    required this.search,
    required this.state,
    required this.names,
  });

  final _HuntSearchSnapshot search;
  final WildState state;
  final Gen3NamedResources names;
}

class _SavedCalibrationTarget {
  const _SavedCalibrationTarget({
    required this.id,
    required this.target,
    required this.savedAt,
  });

  final int id;
  final _CalibrationTarget target;
  final DateTime savedAt;
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
    this.delay = 0,
    this.results = const <_HuntResult>[],
    this.resultLimitReached = false,
    this.searching = false,
    this.searchProgress,
  });

  final String? error;
  final Gen3NamedResources? names;
  final _HuntSearchSnapshot? search;
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
    required this.names,
    required this.locations,
    required this.personal,
    required this.wild,
    required this.staticEncounters,
    required this.speciesOptions,
  });

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

String _abilitySlotLabel({
  required BuildContext context,
  required int slot,
  required String name,
}) {
  return AppLocalizations.of(context)!.abilitySlot(slot + 1, name);
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
