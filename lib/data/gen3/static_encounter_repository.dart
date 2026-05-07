import 'dart:convert';

import 'package:flutter/services.dart';

import '../../app/profile.dart';
import 'static_encounters.dart';

class Gen3StaticEncounterRepository {
  const Gen3StaticEncounterRepository._(this.templates);

  final List<StaticEncounterTemplate> templates;

  static Future<Gen3StaticEncounterRepository> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/gen3/static_encounters.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final templates = (json['encounters'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(StaticEncounterTemplate.fromJson)
        .toList(growable: false);
    return Gen3StaticEncounterRepository._(templates);
  }

  List<StaticEncounterTemplate> templatesForGame(GameVersion game) {
    return templates.where((template) => template.game == game).toList();
  }

  List<StaticEncounterTemplate> templatesForSpecies({
    required GameVersion game,
    required int speciesId,
  }) {
    return templates.where((template) {
      return template.game == game && template.species == speciesId;
    }).toList(growable: false);
  }
}
