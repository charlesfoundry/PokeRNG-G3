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
    required this.observedIvs,
    required this.personalData,
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
  final Ivs observedIvs;
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

    for (final state in generator.generate()) {
      if (!_matches(state)) {
        continue;
      }
      return WildCalibrationResult(
        hitAdvance: state.advance,
        targetAdvance: initialAdvance,
        delta: state.advance - initialAdvance,
        suggestedDelay: delay + (initialAdvance - state.advance),
      );
    }
    return null;
  }

  bool _matches(WildState state) {
    if (state.species != speciesId) {
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
    return _sameIvs(state.ivs, observedIvs);
  }
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
