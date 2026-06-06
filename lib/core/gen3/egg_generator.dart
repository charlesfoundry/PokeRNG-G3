import '../../data/gen3/personal_data.dart';
import 'poke_rng.dart';
import 'pokemon_attributes.dart';
import 'wild_calibration.dart';

enum EggMethod3 {
  emeraldBred,
  emeraldBredSplit,
  emeraldBredAlternate,
  rsFrLgBred,
  rsFrLgBredSplit,
  rsFrLgBredAlternate,
  rsFrLgBredMixed,
}

enum DaycareParentGender { male, female, genderless, ditto }

class DaycareParent3 {
  const DaycareParent3({
    required this.ivs,
    required this.gender,
    required this.nature,
    this.item = 0,
    this.ability = 0,
  });

  final Ivs ivs;
  final DaycareParentGender gender;
  final Nature nature;
  final int item;
  final int ability;

  int ivAt(int stat) => ivs.ordered[stat];
}

class Daycare3 {
  const Daycare3({
    required this.parentA,
    required this.parentB,
    required this.eggSpecies,
    this.masuda = false,
  });

  final DaycareParent3 parentA;
  final DaycareParent3 parentB;
  final int eggSpecies;
  final bool masuda;

  DaycareParent3 parent(int index) => index == 0 ? parentA : parentB;
}

class EggGenerator3 {
  const EggGenerator3({
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

  List<EggState3> generate({int heldSeed = 0, int pickupSeed = 0}) {
    return generateOrdered(heldSeed: heldSeed, pickupSeed: pickupSeed).toList();
  }

  Iterable<EggState3> generateOrdered({
    int heldSeed = 0,
    int pickupSeed = 0,
  }) sync* {
    switch (method) {
      case EggMethod3.emeraldBred:
      case EggMethod3.emeraldBredSplit:
      case EggMethod3.emeraldBredAlternate:
        yield* _generateEmeraldOrdered();
      case EggMethod3.rsFrLgBred:
      case EggMethod3.rsFrLgBredSplit:
      case EggMethod3.rsFrLgBredAlternate:
      case EggMethod3.rsFrLgBredMixed:
        yield* _generateRsFrLgOrdered(
          heldSeed: heldSeed,
          pickupSeed: pickupSeed,
        );
    }
  }

  Iterable<EggState3> _generateEmeraldOrdered() sync* {
    final held = _generateEmeraldHeld();
    if (held.isEmpty) {
      return;
    }
    held.sort(_compareEggStates);
    final pickupFrames = _generateEmeraldPickupFrames();
    final baseInfo = _eggPersonalInfo(daycare.eggSpecies);
    final maleInfo = _alternateMaleInfo(daycare.eggSpecies);

    for (final heldState in held) {
      final info = _resolveEggInfo(
        pid: heldState.pid.value,
        base: baseInfo,
        male: maleInfo,
      );
      final species = _resolveEggSpecies(heldState.pid.value);
      for (final frame in pickupFrames) {
        yield heldState.withPickup(
          pickupAdvances: frame.pickupAdvances,
          species: species,
          ivs: frame.ivs,
          inheritance: frame.inheritance,
          personalInfo: info,
        );
      }
    }
  }

  Iterable<EggState3> _generateRsFrLgOrdered({
    required int heldSeed,
    required int pickupSeed,
  }) sync* {
    final held = _generateRsFrLgHeld(heldSeed);
    if (held.isEmpty) {
      return;
    }
    held.sort(_compareEggStates);
    final pickupFrames = _generateRsFrLgPickupFrames(pickupSeed);
    final baseInfo = _eggPersonalInfo(daycare.eggSpecies);
    final maleInfo = _alternateMaleInfo(daycare.eggSpecies);

    for (final heldState in held) {
      for (final frame in pickupFrames) {
        final pidValue =
            ((frame.high << 16) | heldState.pid.value) & 0xffffffff;
        final pid = PokemonPid(pidValue);
        final info = _resolveEggInfo(
          pid: pidValue,
          base: baseInfo,
          male: maleInfo,
        );
        yield heldState.withPickup(
          pickupAdvances: frame.pickupAdvances,
          species: _resolveEggSpecies(pidValue),
          pid: pid,
          shiny: pid.isShiny(tid: tid, sid: sid),
          nature: pid.nature,
          ivs: frame.ivs,
          inheritance: frame.inheritance,
          personalInfo: info,
        );
      }
    }
  }

  List<EggState3> _generateEmeraldHeld() {
    final baseInfo = _eggPersonalInfo(daycare.eggSpecies);
    final maleInfo = _alternateMaleInfo(daycare.eggSpecies);
    final everstoneParent = _emeraldEverstoneParent();
    final everstone = everstoneParent == null
        ? false
        : daycare.parent(everstoneParent).item == 1;

    var rng = PokeRng(0).advance(initialAdvances + offset);
    var val = initialAdvances + offset + 1;
    final states = <EggState3>[];

    for (var cnt = 0; cnt <= maxAdvances; cnt += 1, val += 1) {
      final compatibilityCheck = rng.nextU16();
      if (((compatibilityCheck.value * 100) ~/ 0xffff) < compatibility) {
        for (var redraw = minRedraws; redraw <= maxRedraws; redraw += 1) {
          var go = PokeRng(compatibilityCheck.seed);
          final pidOffset = calibration + 3 * redraw;
          if (everstone) {
            final everstoneCheck = go.nextU16();
            go = PokeRng(everstoneCheck.seed);
            final forceNature = (everstoneCheck.value >>> 15) == 0;
            if (forceNature) {
              final state = _generateEmeraldEverstoneState(
                go: go,
                val: val,
                pidOffset: pidOffset,
                everstoneParent: everstoneParent,
              );
              if (state == null) {
                continue;
              }
              final info = _resolveEggInfo(
                pid: state.value,
                base: baseInfo,
                male: maleInfo,
              );
              final species = _resolveEggSpecies(state.value);
              states.add(
                EggState3.held(
                  advances: (initialAdvances + cnt - pidOffset) & 0xffffffff,
                  redraws: redraw,
                  species: species,
                  pid: PokemonPid(state.value),
                  gender: PokemonPid(
                    state.value,
                  ).gender(genderRatio: info.genderRatio),
                  shiny: PokemonPid(state.value).isShiny(tid: tid, sid: sid),
                  abilitySlot: state.value & 1,
                  nature: PokemonPid(state.value).nature,
                  personalInfo: info,
                ),
              );
              continue;
            }
          }

          var trng = PokeRng((val - pidOffset) & 0xffff);
          int pid;

          final low = go.nextU16Bounded(0xfffe);
          go = PokeRng(low.seed);
          final highSeed = PokeRng.nextSeed(trng.seed);
          trng = PokeRng(highSeed);
          pid = (low.value + 1) | (trng.seed & 0xffff0000);

          final info = _resolveEggInfo(
            pid: pid,
            base: baseInfo,
            male: maleInfo,
          );
          final species = _resolveEggSpecies(pid);
          states.add(
            EggState3.held(
              advances: (initialAdvances + cnt - pidOffset) & 0xffffffff,
              redraws: redraw,
              species: species,
              pid: PokemonPid(pid),
              gender: PokemonPid(pid).gender(genderRatio: info.genderRatio),
              shiny: PokemonPid(pid).isShiny(tid: tid, sid: sid),
              abilitySlot: pid & 1,
              nature: PokemonPid(pid).nature,
              personalInfo: info,
            ),
          );
        }
      }
      rng = PokeRng(PokeRng.nextSeed(rng.seed));
    }

    return states;
  }

  PokemonPid? _generateEmeraldEverstoneState({
    required PokeRng go,
    required int val,
    required int pidOffset,
    required int everstoneParent,
  }) {
    var pidRng = go;
    var highRng = PokeRng((val - pidOffset) & 0xffff);

    for (var attempts = 0; attempts < 17; attempts += 1) {
      final low = pidRng.nextU16();
      pidRng = PokeRng(low.seed);
      final highSeed = PokeRng.nextSeed(highRng.seed);
      highRng = PokeRng(highSeed);
      final pid = low.value | (highRng.seed & 0xffff0000);
      if (PokemonPid(pid).nature == daycare.parent(everstoneParent).nature) {
        return PokemonPid(pid);
      }
    }

    return null;
  }

  List<_EmeraldPickupFrame> _generateEmeraldPickupFrames() {
    final frames = <_EmeraldPickupFrame>[];
    var rng = PokeRng(0).advance(initialPickupAdvances + pickupOffset);
    final params = _methodParams(method);

    for (var cnt = 0; cnt <= maxPickupAdvances; cnt += 1) {
      var go = rng.advance(params.iv1);
      final ivWord1 = go.nextU16();
      go = PokeRng(ivWord1.seed).advance(params.iv2);
      final ivWord2 = go.nextU16();
      go = PokeRng(ivWord2.seed).advance(params.inheritance);

      final inherited = _inheritanceInputs(go);
      final inheritanceResult = _applyEmeraldInheritance(
        _ivsFromWords(ivWord1.value, ivWord2.value),
        inherited.inheritance,
        inherited.parents,
      );

      frames.add(
        _EmeraldPickupFrame(
          pickupAdvances: initialPickupAdvances + cnt,
          ivs: inheritanceResult.ivs,
          inheritance: inheritanceResult.inheritance,
        ),
      );
      rng = PokeRng(PokeRng.nextSeed(rng.seed));
    }

    return frames;
  }

  List<EggState3> _generateRsFrLgHeld(int seed) {
    final baseInfo = _eggPersonalInfo(daycare.eggSpecies);
    final maleInfo = _alternateMaleInfo(daycare.eggSpecies);
    var rng = PokeRng(seed).advance(initialAdvances + offset);
    final states = <EggState3>[];

    for (var cnt = 0; cnt <= maxAdvances; cnt += 1) {
      var go = rng;
      final compatibilityCheck = go.nextU16();
      go = PokeRng(compatibilityCheck.seed);
      if (((compatibilityCheck.value * 100) ~/ 0xffff) < compatibility) {
        final low = go.nextU16Bounded(0xfffe);
        final pidLow = low.value + 1;
        final info = _resolveEggInfo(
          pid: pidLow,
          base: baseInfo,
          male: maleInfo,
        );
        states.add(
          EggState3.held(
            advances: initialAdvances + cnt,
            redraws: 0,
            species: _resolveEggSpecies(pidLow),
            pid: PokemonPid(pidLow),
            gender: PokemonPid(pidLow).gender(genderRatio: info.genderRatio),
            shiny: false,
            abilitySlot: pidLow & 1,
            nature: Nature.hardy,
            personalInfo: info,
          ),
        );
      }
      rng = PokeRng(PokeRng.nextSeed(rng.seed));
    }

    return states;
  }

  List<_RsFrLgPickupFrame> _generateRsFrLgPickupFrames(int seed) {
    final frames = <_RsFrLgPickupFrame>[];
    final params = _methodParams(method);
    var rng = PokeRng(seed).advance(initialPickupAdvances + pickupOffset);

    for (var cnt = 0; cnt <= maxPickupAdvances; cnt += 1) {
      var go = rng;
      final high = go.nextU16();
      go = PokeRng(high.seed).advance(params.iv1);
      final ivWord1 = go.nextU16();
      go = PokeRng(ivWord1.seed).advance(params.iv2);
      final ivWord2 = go.nextU16();
      go = PokeRng(ivWord2.seed).advance(params.inheritance);

      final inherited = _inheritanceInputs(go);
      final inheritanceResult = _applyRsFrLgInheritance(
        _ivsFromWords(ivWord1.value, ivWord2.value),
        inherited.inheritance,
        inherited.parents,
      );

      frames.add(
        _RsFrLgPickupFrame(
          pickupAdvances: initialPickupAdvances + cnt,
          high: high.value,
          ivs: inheritanceResult.ivs,
          inheritance: inheritanceResult.inheritance,
        ),
      );
      rng = PokeRng(PokeRng.nextSeed(rng.seed));
    }

    return frames;
  }

  int? _emeraldEverstoneParent() {
    int? parent;
    for (var index = 0; index < 2; index += 1) {
      if (daycare.parent(index).gender == DaycareParentGender.female) {
        parent = index;
      }
    }
    for (var index = 0; index < 2; index += 1) {
      if (daycare.parent(index).gender == DaycareParentGender.ditto) {
        parent = index;
      }
    }
    return parent;
  }

  Gen3PersonalInfo _eggPersonalInfo(int species) {
    final info = personalData[species];
    if (info == null) {
      throw ArgumentError.value(species, 'species', 'missing personal data');
    }
    return info;
  }

  Gen3PersonalInfo? _alternateMaleInfo(int species) {
    if (species == 29) {
      return personalData[32];
    }
    if (species == 314) {
      return personalData[313];
    }
    return null;
  }

  Gen3PersonalInfo _resolveEggInfo({
    required int pid,
    required Gen3PersonalInfo base,
    required Gen3PersonalInfo? male,
  }) {
    if (male != null && (pid & 0x8000) != 0) {
      return male;
    }
    return base;
  }

  int _resolveEggSpecies(int pid) {
    if (daycare.eggSpecies == 29 && (pid & 0x8000) != 0) {
      return 32;
    }
    if (daycare.eggSpecies == 314 && (pid & 0x8000) != 0) {
      return 313;
    }
    return daycare.eggSpecies;
  }

  Ivs _ivsFromWords(int word1, int word2) => Ivs.fromWords(word1, word2);

  _InheritanceInputs _inheritanceInputs(PokeRng rng) {
    var go = rng;
    final inh0 = go.nextU16Bounded(6);
    go = PokeRng(inh0.seed);
    final inh1 = go.nextU16Bounded(5);
    go = PokeRng(inh1.seed);
    final inh2 = go.nextU16Bounded(4);
    go = PokeRng(inh2.seed);

    final par0 = go.nextU16Bounded(2);
    go = PokeRng(par0.seed);
    final par1 = go.nextU16Bounded(2);
    go = PokeRng(par1.seed);
    final par2 = go.nextU16Bounded(2);

    return _InheritanceInputs(
      inheritance: [inh0.value, inh1.value, inh2.value],
      parents: [par0.value, par1.value, par2.value],
    );
  }

  _InheritanceResult _applyEmeraldInheritance(
    Ivs baseIvs,
    List<int> inherited,
    List<int> parents,
  ) {
    const available1 = [0, 1, 2, 5, 3, 4];
    const available2 = [1, 2, 5, 3, 4];
    const available3 = [1, 5, 3, 4];
    final ivs = baseIvs.ordered.toList();
    final inheritance = List<int>.filled(6, 0);

    void inherit(int stat, int parent) {
      ivs[stat] = daycare.parent(parent).ivAt(stat);
      inheritance[stat] = parent + 1;
    }

    inherit(available1[inherited[0]], parents[0]);
    inherit(available2[inherited[1]], parents[1]);
    inherit(available3[inherited[2]], parents[2]);

    return _InheritanceResult(
      ivs: _ivsFromOrdered(ivs),
      inheritance: inheritance,
    );
  }

  _InheritanceResult _applyRsFrLgInheritance(
    Ivs baseIvs,
    List<int> inherited,
    List<int> parents,
  ) {
    const order = [0, 1, 2, 5, 3, 4];
    final available = [0, 1, 2, 3, 4, 5];
    final ivs = baseIvs.ordered.toList();
    final inheritance = List<int>.filled(6, 0);

    void avoid(int index, int size) {
      for (var i = index; i < size; i += 1) {
        available[i] = available[i + 1];
      }
    }

    void inheritAt(int inheritedIndex, int parent, int size) {
      final statIndex = available[inheritedIndex];
      final stat = order[statIndex];
      ivs[stat] = daycare.parent(parent).ivAt(stat);
      inheritance[stat] = parent + 1;
      avoid(statIndex, size);
    }

    inheritAt(inherited[0], parents[0], 5);
    inheritAt(inherited[1], parents[1], 4);
    inheritAt(inherited[2], parents[2], 3);

    return _InheritanceResult(
      ivs: _ivsFromOrdered(ivs),
      inheritance: inheritance,
    );
  }

  _EggMethodParams _methodParams(EggMethod3 method) {
    return switch (method) {
      EggMethod3.emeraldBred => const _EggMethodParams(0, 0, 1),
      EggMethod3.emeraldBredSplit => const _EggMethodParams(0, 1, 1),
      EggMethod3.emeraldBredAlternate => const _EggMethodParams(0, 0, 2),
      EggMethod3.rsFrLgBred => const _EggMethodParams(1, 0, 1),
      EggMethod3.rsFrLgBredSplit => const _EggMethodParams(0, 1, 1),
      EggMethod3.rsFrLgBredAlternate => const _EggMethodParams(1, 0, 2),
      EggMethod3.rsFrLgBredMixed => const _EggMethodParams(0, 0, 2),
    };
  }
}

class EggState3 {
  const EggState3({
    required this.advances,
    required this.pickupAdvances,
    required this.redraws,
    required this.species,
    required this.pid,
    required this.ivs,
    required this.inheritance,
    required this.abilitySlot,
    required this.abilityId,
    required this.gender,
    required this.level,
    required this.nature,
    required this.shiny,
    required this.stats,
  });

  factory EggState3.held({
    required int advances,
    required int redraws,
    required int species,
    required PokemonPid pid,
    required PokemonGender gender,
    required bool shiny,
    required int abilitySlot,
    required Nature nature,
    required Gen3PersonalInfo personalInfo,
  }) {
    return EggState3(
      advances: advances,
      pickupAdvances: 0,
      redraws: redraws,
      species: species,
      pid: pid,
      ivs: const Ivs(
        hp: 0,
        attack: 0,
        defense: 0,
        specialAttack: 0,
        specialDefense: 0,
        speed: 0,
      ),
      inheritance: const [0, 0, 0, 0, 0, 0],
      abilitySlot: abilitySlot,
      abilityId: personalInfo.abilityIds[abilitySlot],
      gender: gender,
      level: 5,
      nature: nature,
      shiny: shiny,
      stats: calculateGen3Stats(
        personalInfo: personalInfo,
        ivs: const Ivs(
          hp: 0,
          attack: 0,
          defense: 0,
          specialAttack: 0,
          specialDefense: 0,
          speed: 0,
        ),
        nature: nature,
        level: 5,
      ),
    );
  }

  final int advances;
  final int pickupAdvances;
  final int redraws;
  final int species;
  final PokemonPid pid;
  final Ivs ivs;
  final List<int> inheritance;
  final int abilitySlot;
  final int abilityId;
  final PokemonGender gender;
  final int level;
  final Nature nature;
  final bool shiny;
  final PokemonStats stats;

  EggState3 withPickup({
    required int pickupAdvances,
    required int species,
    PokemonPid? pid,
    bool? shiny,
    Nature? nature,
    required Ivs ivs,
    required List<int> inheritance,
    required Gen3PersonalInfo personalInfo,
  }) {
    final nextPid = pid ?? this.pid;
    final nextNature = nature ?? this.nature;
    return EggState3(
      advances: advances,
      pickupAdvances: pickupAdvances,
      redraws: redraws,
      species: species,
      pid: nextPid,
      ivs: ivs,
      inheritance: List<int>.unmodifiable(inheritance),
      abilitySlot: nextPid.abilitySlot,
      abilityId: personalInfo.abilityIds[nextPid.abilitySlot],
      gender: nextPid.gender(genderRatio: personalInfo.genderRatio),
      level: level,
      nature: nextNature,
      shiny: shiny ?? this.shiny,
      stats: calculateGen3Stats(
        personalInfo: personalInfo,
        ivs: ivs,
        nature: nextNature,
        level: level,
      ),
    );
  }
}

class _EggMethodParams {
  const _EggMethodParams(this.iv1, this.iv2, this.inheritance);

  final int iv1;
  final int iv2;
  final int inheritance;
}

class _EmeraldPickupFrame {
  const _EmeraldPickupFrame({
    required this.pickupAdvances,
    required this.ivs,
    required this.inheritance,
  });

  final int pickupAdvances;
  final Ivs ivs;
  final List<int> inheritance;
}

class _RsFrLgPickupFrame {
  const _RsFrLgPickupFrame({
    required this.pickupAdvances,
    required this.high,
    required this.ivs,
    required this.inheritance,
  });

  final int pickupAdvances;
  final int high;
  final Ivs ivs;
  final List<int> inheritance;
}

class _InheritanceInputs {
  const _InheritanceInputs({required this.inheritance, required this.parents});

  final List<int> inheritance;
  final List<int> parents;
}

class _InheritanceResult {
  const _InheritanceResult({required this.ivs, required this.inheritance});

  final Ivs ivs;
  final List<int> inheritance;
}

Ivs _ivsFromOrdered(List<int> values) {
  return Ivs(
    hp: values[0],
    attack: values[1],
    defense: values[2],
    specialAttack: values[3],
    specialDefense: values[4],
    speed: values[5],
  );
}

int _compareEggStates(EggState3 left, EggState3 right) {
  final advanceCompare = left.advances.compareTo(right.advances);
  if (advanceCompare != 0) {
    return advanceCompare;
  }
  return left.pickupAdvances.compareTo(right.pickupAdvances);
}
