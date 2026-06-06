import 'dart:convert';

import 'package:flutter/services.dart';

import '../../app/profile.dart';
import 'wild_encounters.dart';

class Gen3WildEncounterRepository {
  const Gen3WildEncounterRepository._(this.areas);

  final List<WildEncounterArea> areas;

  static Future<Gen3WildEncounterRepository> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/gen3/wild_encounters.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final areas = (json['areas'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WildEncounterArea.fromJson)
        .toList(growable: false);
    return Gen3WildEncounterRepository._(areas);
  }

  List<WildEncounterArea> areasForSpecies({
    required GameVersion game,
    required int speciesId,
  }) {
    return areas.where((area) {
      return area.game == game &&
          area.slots.any((slot) => slot.species == speciesId);
    }).toList(growable: false);
  }
}
