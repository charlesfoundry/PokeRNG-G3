enum Nature {
  hardy,
  lonely,
  brave,
  adamant,
  naughty,
  bold,
  docile,
  relaxed,
  impish,
  lax,
  timid,
  hasty,
  serious,
  jolly,
  naive,
  modest,
  mild,
  quiet,
  bashful,
  rash,
  calm,
  gentle,
  sassy,
  careful,
  quirky,
}

enum HiddenPowerType {
  fighting,
  flying,
  poison,
  ground,
  rock,
  bug,
  ghost,
  steel,
  fire,
  water,
  grass,
  electric,
  psychic,
  ice,
  dragon,
  dark,
}

enum PokemonGender { male, female, genderless }

class Ivs {
  const Ivs({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
  });

  factory Ivs.fromWords(int word1, int word2) {
    return Ivs(
      hp: word1 & 0x1f,
      attack: (word1 >>> 5) & 0x1f,
      defense: (word1 >>> 10) & 0x1f,
      speed: word2 & 0x1f,
      specialAttack: (word2 >>> 5) & 0x1f,
      specialDefense: (word2 >>> 10) & 0x1f,
    );
  }

  final int hp;
  final int attack;
  final int defense;
  final int specialAttack;
  final int specialDefense;
  final int speed;

  List<int> get ordered => [
    hp,
    attack,
    defense,
    specialAttack,
    specialDefense,
    speed,
  ];

  HiddenPower get hiddenPower {
    final typeBits =
        (hp & 1) +
        2 * (attack & 1) +
        4 * (defense & 1) +
        8 * (speed & 1) +
        16 * (specialAttack & 1) +
        32 * (specialDefense & 1);

    final powerBits =
        ((hp & 2) >>> 1) +
        2 * ((attack & 2) >>> 1) +
        4 * ((defense & 2) >>> 1) +
        8 * ((speed & 2) >>> 1) +
        16 * ((specialAttack & 2) >>> 1) +
        32 * ((specialDefense & 2) >>> 1);

    return HiddenPower(
      type: HiddenPowerType.values[(typeBits * 15) ~/ 63],
      power: ((powerBits * 40) ~/ 63) + 30,
    );
  }

  @override
  String toString() {
    return '$hp/$attack/$defense/$specialAttack/$specialDefense/$speed';
  }
}

class HiddenPower {
  const HiddenPower({required this.type, required this.power});

  final HiddenPowerType type;
  final int power;
}

class PokemonPid {
  const PokemonPid(this.value);

  final int value;

  int get low => value & 0xffff;
  int get high => value >>> 16;
  Nature get nature => Nature.values[value % Nature.values.length];
  int get abilitySlot => value & 1;

  PokemonGender gender({required int genderRatio}) {
    return switch (genderRatio) {
      255 => PokemonGender.genderless,
      254 => PokemonGender.female,
      0 => PokemonGender.male,
      _ =>
        (value & 0xff) < genderRatio
            ? PokemonGender.female
            : PokemonGender.male,
    };
  }

  bool isShiny({required int tid, required int sid}) {
    return (tid ^ sid ^ low ^ high) < 8;
  }

  @override
  String toString() => value.toRadixString(16).padLeft(8, '0').toUpperCase();
}
