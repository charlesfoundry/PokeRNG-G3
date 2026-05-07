import 'poke_rng.dart';
import 'pokemon_attributes.dart';

enum StaticMethod { method1, method2, method4 }

class StaticGenerator {
  const StaticGenerator({
    required this.seed,
    this.initialAdvance = 0,
    required this.maxAdvances,
    this.method = StaticMethod.method1,
    this.tid = 0,
    this.sid = 0,
    this.genderRatio = 255,
    this.level = 0,
    this.buggedRoamer = false,
  });

  final int seed;
  final int initialAdvance;
  final int maxAdvances;
  final StaticMethod method;
  final int tid;
  final int sid;
  final int genderRatio;
  final int level;
  final bool buggedRoamer;

  Iterable<StaticState> generate() sync* {
    var baseRng = PokeRng(seed).advance(initialAdvance);
    for (var advance = initialAdvance; advance <= maxAdvances; advance += 1) {
      yield _stateFromBaseSeed(advance, baseRng.seed);
      baseRng = PokeRng(PokeRng.nextSeed(baseRng.seed));
    }
  }

  StaticState generateAt(int advance) {
    return switch (method) {
      StaticMethod.method1 || StaticMethod.method2 || StaticMethod.method4 =>
        _stateFromBaseSeed(advance, PokeRng(seed).advance(advance).seed),
    };
  }

  StaticState _stateFromBaseSeed(int advance, int baseSeed) {
    var rng = PokeRng(baseSeed);
    final pidLow = rng.nextU16();
    rng = PokeRng(pidLow.seed);
    final pidHigh = rng.nextU16();
    rng = PokeRng(pidHigh.seed);
    final rawIvWord1 = rng.nextU16();
    final ivWord1 = buggedRoamer ? rawIvWord1.value & 0xff : rawIvWord1.value;
    rng = PokeRng(rawIvWord1.seed);
    if (method == StaticMethod.method4) {
      rng = PokeRng(PokeRng.nextSeed(rng.seed));
    }
    final ivWord2 = buggedRoamer ? 0 : rng.nextU16().value;

    final pid = PokemonPid((pidHigh.value << 16) | pidLow.value);
    final ivs = Ivs.fromWords(ivWord1, ivWord2);

    return StaticState(
      advance: advance,
      seed: seed,
      pid: pid,
      ivs: ivs,
      nature: pid.nature,
      abilitySlot: pid.abilitySlot,
      gender: pid.gender(genderRatio: genderRatio),
      level: level,
      shiny: pid.isShiny(tid: tid, sid: sid),
    );
  }
}

class StaticState {
  const StaticState({
    required this.advance,
    required this.seed,
    required this.pid,
    required this.ivs,
    required this.nature,
    required this.abilitySlot,
    required this.gender,
    required this.level,
    required this.shiny,
  });

  final int advance;
  final int seed;
  final PokemonPid pid;
  final Ivs ivs;
  final Nature nature;
  final int abilitySlot;
  final PokemonGender gender;
  final int level;
  final bool shiny;
}
