import '../../data/gen3/personal_data.dart';
import '../../data/gen3/wild_encounters.dart';
import 'pokemon_attributes.dart';
import 'wild_generator.dart';

class WildCalibrationRequest {
  const WildCalibrationRequest({
    required this.seed,
    required this.initialAdvance,
    required this.maxAdvance,
    required this.delay,
    required this.method,
    required this.area,
    required this.tid,
    required this.sid,
    required this.speciesId,
    required this.personalData,
    this.observedLevel,
    this.observedIvs,
    this.observedStats,
    this.observedNature,
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
  final int? observedLevel;
  final Ivs? observedIvs;
  final PokemonStats? observedStats;
  final Nature? observedNature;
  final int? abilitySlot;
  final PokemonGender? gender;
  final int? encounterSlot;
  final Nature? synchronizeNature;
  final bool pressureLead;
  final bool staticLead;
  final bool magnetPullLead;
  final CuteCharmLead? cuteCharmLead;
  final bool feebasTile;
  final Gen3PersonalData personalData;

  WildCalibrationResult? calibrate() {
    final matches = findMatches(limit: 1);
    if (matches.isEmpty) {
      return null;
    }
    final hit = matches.first;
    return WildCalibrationResult(
      hitAdvance: hit.state.advance,
      targetAdvance: initialAdvance,
      delta: hit.state.advance - initialAdvance,
      suggestedDelay: delay + (initialAdvance - hit.state.advance),
    );
  }

  List<WildCalibrationHit> findMatches({int limit = 20}) {
    final ivCandidates = _ivCandidates();
    if (ivCandidates?.isEmpty ?? false) {
      return const [];
    }

    final generator = WildGenerator(
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

    final results = <WildCalibrationHit>[];
    for (final state in generator.generate()) {
      if (!_matches(state, ivCandidates)) {
        continue;
      }
      final personalInfo = personalData[state.species];
      results.add(
        WildCalibrationHit(
          method: method,
          state: state,
          stats: personalInfo == null
              ? null
              : calculateGen3Stats(
                  personalInfo: personalInfo,
                  ivs: state.ivs,
                  nature: state.nature,
                  level: state.level,
                ),
        ),
      );
      if (results.length >= limit) {
        break;
      }
    }
    return results;
  }

  List<List<int>>? _ivCandidates() {
    final stats = observedStats;
    final nature = observedNature;
    final level = observedLevel;
    final personalInfo = personalData[speciesId];
    if (stats == null || nature == null || level == null) {
      return null;
    }
    if (personalInfo == null) {
      return const [];
    }
    final candidates = possibleGen3IvValuesForStats(
      personalInfo: personalInfo,
      stats: stats,
      nature: nature,
      level: level,
    );
    if (candidates.any((values) => values.isEmpty)) {
      return const [];
    }
    return candidates;
  }

  bool _matches(WildState state, List<List<int>>? ivCandidates) {
    if (state.species != speciesId) {
      return false;
    }
    if (observedLevel != null && state.level != observedLevel) {
      return false;
    }
    if (observedNature != null && state.nature != observedNature) {
      return false;
    }
    if (abilitySlot != null && state.abilitySlot != abilitySlot) {
      return false;
    }
    if (gender != null && state.gender != gender) {
      return false;
    }
    if (encounterSlot != null && state.encounterSlot != encounterSlot) {
      return false;
    }
    if (observedIvs != null && !_sameIvs(state.ivs, observedIvs!)) {
      return false;
    }
    if (ivCandidates != null && !_ivCandidatesAllow(state.ivs, ivCandidates)) {
      return false;
    }
    if (observedStats != null && ivCandidates == null) {
      final personalInfo = personalData[state.species];
      if (personalInfo == null) {
        return false;
      }
      final stats = calculateGen3Stats(
        personalInfo: personalInfo,
        ivs: state.ivs,
        nature: state.nature,
        level: state.level,
      );
      if (!_sameStats(stats, observedStats!)) {
        return false;
      }
    }
    return true;
  }
}

class WildCalibrationHit {
  const WildCalibrationHit({
    required this.method,
    required this.state,
    required this.stats,
  });

  final WildMethod method;
  final WildState state;
  final PokemonStats? stats;
}

class WildCalibrationResult {
  const WildCalibrationResult({
    required this.hitAdvance,
    required this.targetAdvance,
    required this.delta,
    required this.suggestedDelay,
  });

  final int hitAdvance;
  final int targetAdvance;
  final int delta;
  final int suggestedDelay;
}

PokemonStats calculateGen3Stats({
  required Gen3PersonalInfo personalInfo,
  required Ivs ivs,
  required Nature nature,
  required int level,
}) {
  final base = personalInfo.baseStats;
  return PokemonStats(
    hp: (((2 * base.hp + ivs.hp) * level) ~/ 100) + level + 10,
    attack: _nonHpStat(
      base: base.attack,
      iv: ivs.attack,
      level: level,
      nature: nature,
      statIndex: 0,
    ),
    defense: _nonHpStat(
      base: base.defense,
      iv: ivs.defense,
      level: level,
      nature: nature,
      statIndex: 1,
    ),
    specialAttack: _nonHpStat(
      base: base.specialAttack,
      iv: ivs.specialAttack,
      level: level,
      nature: nature,
      statIndex: 3,
    ),
    specialDefense: _nonHpStat(
      base: base.specialDefense,
      iv: ivs.specialDefense,
      level: level,
      nature: nature,
      statIndex: 4,
    ),
    speed: _nonHpStat(
      base: base.speed,
      iv: ivs.speed,
      level: level,
      nature: nature,
      statIndex: 2,
    ),
  );
}

List<List<int>> possibleGen3IvValuesForStats({
  required Gen3PersonalInfo personalInfo,
  required PokemonStats stats,
  required Nature nature,
  required int level,
}) {
  final observed = stats.ordered;
  final possible = List<List<int>>.generate(6, (_) => []);
  for (var iv = 0; iv <= 31; iv += 1) {
    final calculated = calculateGen3Stats(
      personalInfo: personalInfo,
      ivs: Ivs(
        hp: iv,
        attack: iv,
        defense: iv,
        specialAttack: iv,
        specialDefense: iv,
        speed: iv,
      ),
      nature: nature,
      level: level,
    ).ordered;
    for (var index = 0; index < observed.length; index += 1) {
      if (calculated[index] == observed[index]) {
        possible[index].add(iv);
      }
    }
  }
  return possible;
}

int _nonHpStat({
  required int base,
  required int iv,
  required int level,
  required Nature nature,
  required int statIndex,
}) {
  final raw = (((2 * base + iv) * level) ~/ 100) + 5;
  final raised = nature.index ~/ 5;
  final lowered = nature.index % 5;
  if (raised == lowered) {
    return raw;
  }
  if (raised == statIndex) {
    return (raw * 110) ~/ 100;
  }
  if (lowered == statIndex) {
    return (raw * 90) ~/ 100;
  }
  return raw;
}

bool _sameIvs(Ivs left, Ivs right) {
  final a = left.ordered;
  final b = right.ordered;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

bool _ivCandidatesAllow(Ivs ivs, List<List<int>> candidates) {
  final values = ivs.ordered;
  for (var index = 0; index < values.length; index += 1) {
    if (!candidates[index].contains(values[index])) {
      return false;
    }
  }
  return true;
}

bool _sameStats(PokemonStats left, PokemonStats right) {
  final a = left.ordered;
  final b = right.ordered;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
