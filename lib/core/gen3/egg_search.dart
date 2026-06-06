import '../../data/gen3/personal_data.dart';
import 'egg_generator.dart';
import 'pokemon_attributes.dart';
import 'wild_search.dart';

class EggSearchRequest {
  const EggSearchRequest({
    required this.initialAdvances,
    required this.maxAdvances,
    required this.offset,
    required this.initialPickupAdvances,
    required this.maxPickupAdvances,
    required this.pickupOffset,
    required this.calibration,
    required this.minRedraws,
    required this.maxRedraws,
    required this.method,
    required this.compatibility,
    required this.daycare,
    required this.personalData,
    required this.tid,
    required this.sid,
    required this.ivFilter,
    this.heldSeed = 0,
    this.pickupSeed = 0,
    this.resultLimit = 500,
    this.shinyOnly = false,
    this.speciesId,
    this.nature,
    this.hiddenPowerType,
    this.abilitySlot,
    this.gender,
  });

  final int initialAdvances;
  final int maxAdvances;
  final int offset;
  final int initialPickupAdvances;
  final int maxPickupAdvances;
  final int pickupOffset;
  final int calibration;
  final int minRedraws;
  final int maxRedraws;
  final EggMethod3 method;
  final int compatibility;
  final Daycare3 daycare;
  final Gen3PersonalData personalData;
  final int tid;
  final int sid;
  final IvFilter ivFilter;
  final int heldSeed;
  final int pickupSeed;
  final int resultLimit;
  final bool shinyOnly;
  final int? speciesId;
  final Nature? nature;
  final HiddenPowerType? hiddenPowerType;
  final int? abilitySlot;
  final PokemonGender? gender;

  EggGenerator3 createGenerator() {
    return EggGenerator3(
      initialAdvances: initialAdvances,
      maxAdvances: maxAdvances,
      offset: offset,
      initialPickupAdvances: initialPickupAdvances,
      maxPickupAdvances: maxPickupAdvances,
      pickupOffset: pickupOffset,
      calibration: calibration,
      minRedraws: minRedraws,
      maxRedraws: maxRedraws,
      method: method,
      compatibility: compatibility,
      daycare: daycare,
      personalData: personalData,
      tid: tid,
      sid: sid,
    );
  }

  bool matches(EggState3 state) {
    if (speciesId != null && state.species != speciesId) {
      return false;
    }
    if (shinyOnly && !state.shiny) {
      return false;
    }
    if (nature != null && state.nature != nature) {
      return false;
    }
    if (hiddenPowerType != null &&
        state.ivs.hiddenPower.type != hiddenPowerType) {
      return false;
    }
    if (!ivFilter.allows(state.ivs)) {
      return false;
    }
    if (abilitySlot != null && state.abilitySlot != abilitySlot) {
      return false;
    }
    if (gender != null && state.gender != gender) {
      return false;
    }
    return true;
  }

  Iterable<EggState3> generateMatching() sync* {
    final generator = createGenerator();
    for (final state in generator.generateOrdered(
      heldSeed: heldSeed,
      pickupSeed: pickupSeed,
    )) {
      if (matches(state)) {
        yield state;
      }
    }
  }

  EggSearchResult search() {
    final results = <EggState3>[];
    var resultLimitReached = false;
    for (final state in generateMatching()) {
      results.add(state);
      if (results.length >= resultLimit) {
        resultLimitReached = true;
        break;
      }
    }
    return EggSearchResult(
      results: List<EggState3>.unmodifiable(results),
      resultLimitReached: resultLimitReached,
    );
  }
}

class EggSearchResult {
  const EggSearchResult({
    required this.results,
    required this.resultLimitReached,
  });

  final List<EggState3> results;
  final bool resultLimitReached;
}
