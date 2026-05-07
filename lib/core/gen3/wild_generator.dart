import '../../app/profile.dart';
import '../../data/gen3/wild_encounters.dart';
import '../../data/gen3/personal_data.dart';
import 'poke_rng.dart';
import 'pokemon_attributes.dart';

enum WildMethod { method1, method2, method4 }

enum CuteCharmLead { male, female }

class WildGenerator {
  const WildGenerator({
    required this.seed,
    this.initialAdvance = 0,
    required this.maxAdvances,
    required this.method,
    required this.area,
    this.tid = 12345,
    this.sid = 54321,
    this.synchronizeNature,
    this.pressureLead = false,
    this.staticLead = false,
    this.magnetPullLead = false,
    this.cuteCharmLead,
    this.feebasTile = false,
    this.personalData,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvances;
  final WildMethod method;
  final WildEncounterArea area;
  final int tid;
  final int sid;
  final Nature? synchronizeNature;
  final bool pressureLead;
  final bool staticLead;
  final bool magnetPullLead;
  final CuteCharmLead? cuteCharmLead;
  final bool feebasTile;
  final Gen3PersonalData? personalData;

  Iterable<WildState> generate() sync* {
    var baseRng = PokeRng(seed).advance(initialAdvance);
    for (var advance = initialAdvance; advance <= maxAdvances; advance += 1) {
      final state = _generateFromBaseSeed(advance, baseRng.seed);
      if (state != null) {
        yield state;
      }
      baseRng = PokeRng(PokeRng.nextSeed(baseRng.seed));
    }
  }

  WildState generateAt(int advance) {
    final state = _generateFromBaseSeed(
      advance,
      PokeRng(seed).advance(advance).seed,
    );
    if (state == null) {
      throw StateError('No encounter generated at advance $advance.');
    }
    return state;
  }

  WildState? _generateFromBaseSeed(int advance, int baseSeed) {
    var rng = PokeRng(baseSeed);
    if (_usesRseRockSmashCheck()) {
      final rockCheck = rng.nextU16Bounded(2880);
      rng = PokeRng(rockCheck.seed);
      if (rockCheck.value >= area.encounterRate * 16) {
        return null;
      }
    }
    final modifiedSlots = staticLead
        ? _modifiedSlots(typeId: 12)
        : magnetPullLead
        ? _modifiedSlots(typeId: 8)
        : const <int>[];
    final feebas = feebasTile && _isFeebasLocation();
    late int encounterSlot;
    final feebasCheck = feebas ? rng.nextU16Bounded(100) : null;
    if (feebasCheck != null) {
      rng = PokeRng(feebasCheck.seed);
    }
    if (feebasCheck != null && feebasCheck.value < 50) {
      encounterSlot = switch (area.type) {
        WildEncounterType.oldRod => 2,
        WildEncounterType.goodRod => 3,
        _ => 5,
      };
    } else if (modifiedSlots.isNotEmpty) {
      final leadCheck = rng.nextU16Bounded(2);
      rng = PokeRng(leadCheck.seed);
      if (leadCheck.value == 0) {
        final modifiedSlotResult = rng.nextU16Bounded(modifiedSlots.length);
        rng = PokeRng(modifiedSlotResult.seed);
        encounterSlot = modifiedSlots[modifiedSlotResult.value];
      } else {
        final slotResult = rng.nextU16Bounded(100);
        rng = PokeRng(slotResult.seed);
        encounterSlot = hSlot(slotResult.value, area.type);
      }
    } else {
      final slotResult = rng.nextU16Bounded(100);
      rng = PokeRng(slotResult.seed);
      encounterSlot = hSlot(slotResult.value, area.type);
    }
    final slot = _slotForEncounterSlot(encounterSlot);

    final levelRange = slot.maxLevel - slot.minLevel + 1;
    final levelResult = rng.nextU16Bounded(levelRange);
    rng = PokeRng(levelResult.seed);
    var levelRand = levelResult.value;
    if (pressureLead) {
      final pressureResult = rng.nextU16Bounded(2);
      rng = PokeRng(pressureResult.seed);
      if (pressureResult.value == 0) {
        levelRand = slot.maxLevel - slot.minLevel;
      } else if (levelRand != 0) {
        levelRand -= 1;
      }
    }
    final level = slot.minLevel + levelRand;
    final personalInfo = personalData?[slot.species];
    final genderRatio = personalInfo?.genderRatio ?? 255;
    final tanobyChamber = _isTanobyChamber();
    var cuteCharm = false;
    if (cuteCharmLead != null &&
        !tanobyChamber &&
        !_hasFixedGender(genderRatio)) {
      final cuteCharmResult = rng.nextU16Bounded(3);
      rng = PokeRng(cuteCharmResult.seed);
      cuteCharm = cuteCharmResult.value != 0;
    }
    if (_usesEmeraldSafariExtraCall()) {
      rng = rng.advance();
    }

    late Nature nature;
    late PokemonPid pid;
    if (tanobyChamber) {
      do {
        final low = rng.nextU16();
        rng = PokeRng(low.seed);
        final high = rng.nextU16();
        rng = PokeRng(high.seed);
        pid = PokemonPid((low.value << 16) | high.value);
      } while (_unownLetter(pid) != slot.form);
      nature = pid.nature;
    } else {
      if (synchronizeNature != null) {
        final syncCheck = rng.nextU16Bounded(2);
        rng = PokeRng(syncCheck.seed);
        if (syncCheck.value == 0) {
          nature = synchronizeNature!;
        } else {
          final natureResult = rng.nextU16Bounded(Nature.values.length);
          rng = PokeRng(natureResult.seed);
          nature = Nature.values[natureResult.value];
        }
      } else {
        final natureResult = rng.nextU16Bounded(Nature.values.length);
        rng = PokeRng(natureResult.seed);
        nature = Nature.values[natureResult.value];
      }

      while (true) {
        final low = rng.nextU16();
        rng = PokeRng(low.seed);
        final high = rng.nextU16();
        rng = PokeRng(high.seed);
        pid = PokemonPid((high.value << 16) | low.value);
        if (pid.nature == nature &&
            _cuteCharmAllows(pid, genderRatio, cuteCharm)) {
          break;
        }
      }
    }

    if (method == WildMethod.method2) {
      rng = rng.advance();
    }

    final ivWord1 = rng.nextU16();
    rng = PokeRng(ivWord1.seed);

    if (method == WildMethod.method4) {
      rng = rng.advance();
    }

    final ivWord2 = rng.nextU16();
    final ivs = Ivs.fromWords(ivWord1.value, ivWord2.value);

    return WildState(
      advance: advance,
      pid: pid,
      ivs: ivs,
      nature: nature,
      abilitySlot: pid.abilitySlot,
      gender: pid.gender(genderRatio: genderRatio),
      shiny: pid.isShiny(tid: tid, sid: sid),
      encounterSlot: encounterSlot,
      species: slot.species,
      form: slot.form,
      level: level,
    );
  }

  static int hSlot(int rand, WildEncounterType type) {
    final ranges = switch (type) {
      WildEncounterType.oldRod => const [70, 100],
      WildEncounterType.goodRod => const [60, 80, 100],
      WildEncounterType.superRod => const [40, 80, 95, 99, 100],
      WildEncounterType.surfing ||
      WildEncounterType.rockSmash => const [60, 90, 95, 99, 100],
      WildEncounterType.grass => const [
        20,
        40,
        50,
        60,
        70,
        80,
        85,
        90,
        94,
        98,
        99,
        100,
      ],
    };

    for (var slot = 0; slot < ranges.length; slot += 1) {
      if (rand < ranges[slot]) {
        return slot;
      }
    }
    throw StateError('Encounter slot rand out of range: $rand');
  }

  List<int> _modifiedSlots({required int typeId}) {
    final personalData = this.personalData;
    if (personalData == null) {
      return const [];
    }

    final result = <int>[];
    for (var i = 0; i < area.slots.length; i += 1) {
      final info = personalData[area.slots[i].species];
      if (info == null) {
        continue;
      }
      if (info.typeIds.contains(typeId)) {
        result.add(i);
      }
    }

    if (result.length == area.slots.length) {
      return const [];
    }
    return result;
  }

  bool _cuteCharmAllows(PokemonPid pid, int genderRatio, bool active) {
    if (!active || cuteCharmLead == null) {
      return true;
    }
    final lowByte = pid.value & 0xff;
    return switch (cuteCharmLead!) {
      CuteCharmLead.female => lowByte >= genderRatio,
      CuteCharmLead.male => lowByte < genderRatio,
    };
  }

  static bool _hasFixedGender(int genderRatio) {
    return genderRatio == 0 || genderRatio == 254 || genderRatio == 255;
  }

  bool _isFeebasLocation() {
    return area.game == GameVersion.emerald &&
        area.locationId == 33 &&
        (area.type == WildEncounterType.oldRod ||
            area.type == WildEncounterType.goodRod ||
            area.type == WildEncounterType.superRod);
  }

  bool _usesRseRockSmashCheck() {
    return area.game == GameVersion.emerald &&
        area.type == WildEncounterType.rockSmash;
  }

  bool _isTanobyChamber() {
    return (area.game == GameVersion.fireRed ||
            area.game == GameVersion.leafGreen) &&
        area.type == WildEncounterType.grass &&
        area.locationId >= 0 &&
        area.locationId <= 6;
  }

  bool _usesEmeraldSafariExtraCall() {
    return area.game == GameVersion.emerald &&
        {
          20, // Safari Zone South
          72, // Safari Zone Southwest
          73, // Safari Zone North
          74, // Safari Zone Northwest
          97, // Safari Zone Southeast
          98, // Safari Zone Northeast
        }.contains(area.locationId);
  }

  WildSlot _slotForEncounterSlot(int encounterSlot) {
    if (encounterSlot < area.slots.length) {
      return area.slots[encounterSlot];
    }
    if (feebasTile &&
        _isFeebasLocation() &&
        encounterSlot == _feebasSlotIndex()) {
      return const WildSlot(species: 349, minLevel: 20, maxLevel: 25);
    }
    throw RangeError.index(encounterSlot, area.slots, 'encounterSlot');
  }

  int _feebasSlotIndex() {
    return switch (area.type) {
      WildEncounterType.oldRod => 2,
      WildEncounterType.goodRod => 3,
      _ => 5,
    };
  }

  int _unownLetter(PokemonPid pid) {
    final value = pid.value;
    return (((value & 0x3000000) >>> 18) |
            ((value & 0x30000) >>> 12) |
            ((value & 0x300) >>> 6) |
            (value & 0x3)) %
        0x1c;
  }
}

class WildState {
  const WildState({
    required this.advance,
    required this.pid,
    required this.ivs,
    required this.nature,
    required this.abilitySlot,
    required this.gender,
    required this.shiny,
    required this.encounterSlot,
    required this.species,
    required this.form,
    required this.level,
  });

  final int advance;
  final PokemonPid pid;
  final Ivs ivs;
  final Nature nature;
  final int abilitySlot;
  final PokemonGender gender;
  final bool shiny;
  final int encounterSlot;
  final int species;
  final int form;
  final int level;
}
