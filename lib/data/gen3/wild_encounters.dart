import '../../app/profile.dart';

enum WildEncounterType { grass, surfing, rockSmash, oldRod, goodRod, superRod }

extension WildEncounterTypeJson on WildEncounterType {
  String get jsonName {
    return switch (this) {
      WildEncounterType.grass => 'grass',
      WildEncounterType.surfing => 'surfing',
      WildEncounterType.rockSmash => 'rockSmash',
      WildEncounterType.oldRod => 'oldRod',
      WildEncounterType.goodRod => 'goodRod',
      WildEncounterType.superRod => 'superRod',
    };
  }

  static WildEncounterType parse(String value) {
    return WildEncounterType.values.firstWhere(
      (type) => type.jsonName == value,
    );
  }
}

class WildSlot {
  const WildSlot({
    required this.species,
    required this.minLevel,
    required this.maxLevel,
    this.form = 0,
  });

  factory WildSlot.fromJson(Map<String, dynamic> json) {
    return WildSlot(
      species: json['species'] as int,
      minLevel: json['minLevel'] as int,
      maxLevel: json['maxLevel'] as int,
      form: json['form'] as int? ?? 0,
    );
  }

  final int species;
  final int minLevel;
  final int maxLevel;
  final int form;

  Map<String, dynamic> toJson() {
    return {
      'species': species,
      'minLevel': minLevel,
      'maxLevel': maxLevel,
      if (form != 0) 'form': form,
    };
  }
}

class WildEncounterArea {
  const WildEncounterArea({
    required this.game,
    required this.locationId,
    required this.map,
    required this.label,
    required this.type,
    required this.encounterRate,
    required this.slots,
  });

  factory WildEncounterArea.fromJson(Map<String, dynamic> json) {
    return WildEncounterArea(
      game: _parseGame(json['game'] as String),
      locationId: json['locationId'] as int,
      map: json['map'] as String,
      label: json['label'] as String,
      type: WildEncounterTypeJson.parse(json['type'] as String),
      encounterRate: json['encounterRate'] as int,
      slots: (json['slots'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(WildSlot.fromJson)
          .toList(),
    );
  }

  final GameVersion game;
  final int locationId;
  final String map;
  final String label;
  final WildEncounterType type;
  final int encounterRate;
  final List<WildSlot> slots;

  Map<String, dynamic> toJson() {
    return {
      'game': game.jsonName,
      'locationId': locationId,
      'map': map,
      'label': label,
      'type': type.jsonName,
      'encounterRate': encounterRate,
      'slots': slots.map((slot) => slot.toJson()).toList(),
    };
  }
}

GameVersion _parseGame(String value) {
  return GameVersion.values.firstWhere((game) => game.jsonName == value);
}
