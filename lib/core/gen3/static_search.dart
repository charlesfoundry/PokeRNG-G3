import '../../data/gen3/personal_data.dart';
import '../../data/gen3/static_encounters.dart';
import 'pokemon_attributes.dart';
import 'static_generator.dart';
import 'wild_search.dart';

class StaticSearchRequest {
  const StaticSearchRequest({
    required this.seed,
    required this.initialAdvance,
    required this.maxAdvance,
    required this.method,
    required this.template,
    required this.tid,
    required this.sid,
    required this.ivFilter,
    required this.personalData,
    this.resultLimit = 500,
    this.delay = 0,
    this.shinyOnly = false,
    this.nature,
    this.hiddenPowerType,
    this.abilitySlot,
    this.gender,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvance;
  final int delay;
  final StaticMethod method;
  final StaticEncounterTemplate template;
  final int tid;
  final int sid;
  final IvFilter ivFilter;
  final Gen3PersonalData personalData;
  final int resultLimit;
  final bool shinyOnly;
  final Nature? nature;
  final HiddenPowerType? hiddenPowerType;
  final int? abilitySlot;
  final PokemonGender? gender;

  StaticGenerator createGenerator() {
    final info = personalData[template.species];
    return StaticGenerator(
      seed: seed,
      initialAdvance: initialAdvance,
      maxAdvances: maxAdvance,
      method: method,
      tid: tid,
      sid: sid,
      genderRatio: info?.genderRatio ?? 255,
      level: template.level,
      buggedRoamer: template.buggedRoamer,
    );
  }

  bool matches(StaticState state) {
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
    if (abilitySlot != null && state.pid.abilitySlot != abilitySlot) {
      return false;
    }
    if (gender != null && state.gender != gender) {
      return false;
    }
    return true;
  }

  Iterable<StaticSearchHit> generateMatching() sync* {
    for (final state in createGenerator().generate()) {
      if (matches(state)) {
        yield StaticSearchHit(template: template, state: state);
      }
    }
  }

  StaticSearchResult search() {
    final results = <StaticSearchHit>[];
    var resultLimitReached = false;
    for (final hit in generateMatching()) {
      results.add(hit);
      if (results.length >= resultLimit) {
        resultLimitReached = true;
        break;
      }
    }
    return StaticSearchResult(
      results: List<StaticSearchHit>.unmodifiable(results),
      resultLimitReached: resultLimitReached,
    );
  }
}

class StaticSearchHit {
  const StaticSearchHit({required this.template, required this.state});

  final StaticEncounterTemplate template;
  final StaticState state;
}

class StaticSearchResult {
  const StaticSearchResult({
    required this.results,
    required this.resultLimitReached,
  });

  final List<StaticSearchHit> results;
  final bool resultLimitReached;
}
