const int _u32Mask = 0xffffffff;

class PokeRng {
  static const int multiplier = 0x41c64e6d;
  static const int increment = 0x6073;

  const PokeRng(this.seed);

  final int seed;

  PokeRng advance([int count = 1]) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be non-negative');
    }

    var steps = count;
    var accMult = 1;
    var accAdd = 0;
    var curMult = multiplier;
    var curAdd = increment;

    while (steps > 0) {
      if ((steps & 1) != 0) {
        accMult = (accMult * curMult) & _u32Mask;
        accAdd = (accAdd * curMult + curAdd) & _u32Mask;
      }
      curAdd = (curAdd * (curMult + 1)) & _u32Mask;
      curMult = (curMult * curMult) & _u32Mask;
      steps >>>= 1;
    }

    return PokeRng((accMult * (seed & _u32Mask) + accAdd) & _u32Mask);
  }

  RngResult nextU16() {
    final updated = nextSeed(seed);
    return RngResult(seed: updated, value: updated >>> 16);
  }

  RngResult nextU16Bounded(int max) {
    final result = nextU16();
    return RngResult(seed: result.seed, value: result.value % max);
  }

  static int nextSeed(int seed) {
    return ((seed & _u32Mask) * multiplier + increment) & _u32Mask;
  }
}

class RngResult {
  const RngResult({required this.seed, required this.value});

  final int seed;
  final int value;
}
