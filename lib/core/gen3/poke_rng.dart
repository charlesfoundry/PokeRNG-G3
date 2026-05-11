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
        accMult = _mulU32(accMult, curMult);
        accAdd = _addU32(_mulU32(accAdd, curMult), curAdd);
      }
      curAdd = _mulU32(curAdd, _addU32(curMult, 1));
      curMult = _mulU32(curMult, curMult);
      steps >>>= 1;
    }

    return PokeRng(_addU32(_mulU32(accMult, seed), accAdd));
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
    return _addU32(_mulU32(seed, multiplier), increment);
  }

  static int _addU32(int left, int right) {
    return ((left & _u32Mask) + (right & _u32Mask)) & _u32Mask;
  }

  static int _mulU32(int left, int right) {
    final a = left & _u32Mask;
    final b = right & _u32Mask;
    final aLow = a & 0xffff;
    final aHigh = a >>> 16;
    final bLow = b & 0xffff;
    final bHigh = b >>> 16;
    final low = aLow * bLow;
    final high = (low >>> 16) + aHigh * bLow + aLow * bHigh;
    return (low & 0xffff) + ((high & 0xffff) * 0x10000);
  }
}

class RngResult {
  const RngResult({required this.seed, required this.value});

  final int seed;
  final int value;
}
