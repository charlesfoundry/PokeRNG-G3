import '../../data/gen3/personal_data.dart';
import '../../data/gen3/wild_encounters.dart';
import 'pokemon_attributes.dart';
import 'wild_generator.dart';

enum IvComparison {
  lessOrEqual('<='),
  equal('='),
  greaterOrEqual('>=');

  const IvComparison(this.symbol);

  final String symbol;

  bool allows({required int actual, required int expected}) {
    if (expected < 0) {
      return true;
    }
    return switch (this) {
      IvComparison.lessOrEqual => actual <= expected,
      IvComparison.equal => actual == expected,
      IvComparison.greaterOrEqual => actual >= expected,
    };
  }
}

class IvRule {
  const IvRule({required this.value, required this.comparison});

  final int value;
  final IvComparison comparison;

  bool allows(int actual) {
    return comparison.allows(actual: actual, expected: value);
  }
}

class IvFilter {
  const IvFilter({required this.rules});

  final List<IvRule> rules;

  bool allows(Ivs ivs) {
    final values = ivs.ordered;
    for (var i = 0; i < rules.length; i += 1) {
      if (!rules[i].allows(values[i])) {
        return false;
      }
    }
    return true;
  }
}

class WildSearchRequest {
  const WildSearchRequest({
    required this.seed,
    required this.initialAdvance,
    required this.maxAdvance,
    required this.method,
    required this.area,
    required this.tid,
    required this.sid,
    required this.speciesId,
    required this.ivFilter,
    required this.personalData,
    this.resultLimit = 500,
    this.delay = 0,
    this.shinyOnly = false,
    this.nature,
    this.hiddenPowerType,
    this.abilitySlot,
    this.gender,
    this.encounterSlot,
    this.synchronizeNature,
    this.pressureLead = false,
    this.staticLead = false,
    this.magnetPullLead = false,
    this.cuteCharmLead,
    this.feebasTile = false,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvance;
  final int delay;
  final WildMethod method;
  final WildEncounterArea area;
  final int tid;
  final int sid;
  final int speciesId;
  final IvFilter ivFilter;
  final Gen3PersonalData personalData;
  final int resultLimit;
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

  WildGenerator createGenerator() {
    return WildGenerator(
      seed: seed,
      initialAdvance: initialAdvance,
      maxAdvances: maxAdvance,
      method: method,
      area: area,
      tid: tid,
      sid: sid,
      synchronizeNature: synchronizeNature,
      pressureLead: pressureLead,
      staticLead: staticLead,
      magnetPullLead: magnetPullLead,
      cuteCharmLead: cuteCharmLead,
      feebasTile: feebasTile,
      personalData: personalData,
    );
  }

  bool matches(WildState state) {
    if (state.species != speciesId) {
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
    if (abilitySlot != null && state.pid.abilitySlot != abilitySlot) {
      return false;
    }
    if (gender != null && state.gender != gender) {
      return false;
    }
    if (encounterSlot != null && state.encounterSlot != encounterSlot) {
      return false;
    }
    return true;
  }

  Iterable<WildState> generateMatching() sync* {
    for (final state in createGenerator().generate()) {
      if (matches(state)) {
        yield state;
      }
    }
  }

  WildSearchResult search() {
    final results = <WildState>[];
    var resultLimitReached = false;
    for (final state in generateMatching()) {
      results.add(state);
      if (results.length >= resultLimit) {
        resultLimitReached = true;
        break;
      }
    }
    return WildSearchResult(
      results: List<WildState>.unmodifiable(results),
      resultLimitReached: resultLimitReached,
    );
  }
}

class WildSearchResult {
  const WildSearchResult({
    required this.results,
    required this.resultLimitReached,
  });

  final List<WildState> results;
  final bool resultLimitReached;
}
