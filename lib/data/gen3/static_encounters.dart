import '../../app/profile.dart';

enum StaticEncounterType {
  starter('starter'),
  fossil('fossil'),
  gift('gift'),
  gameCorner('gameCorner'),
  stationary('stationary'),
  legend('legend'),
  event('event'),
  roamer('roamer');

  const StaticEncounterType(this.jsonName);

  final String jsonName;

  static StaticEncounterType fromJson(String value) {
    return StaticEncounterType.values.firstWhere(
      (type) => type.jsonName == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}

class StaticEncounterTemplate {
  const StaticEncounterTemplate({
    required this.game,
    required this.type,
    required this.description,
    required this.species,
    required this.form,
    required this.level,
    required this.buggedRoamer,
  });

  factory StaticEncounterTemplate.fromJson(Map<String, dynamic> json) {
    return StaticEncounterTemplate(
      game: _parseGame(json['game'] as String),
      type: StaticEncounterType.fromJson(json['type'] as String),
      description: json['description'] as String,
      species: json['species'] as int,
      form: json['form'] as int,
      level: json['level'] as int,
      buggedRoamer: json['buggedRoamer'] as bool,
    );
  }

  final GameVersion game;
  final StaticEncounterType type;
  final String description;
  final int species;
  final int form;
  final int level;
  final bool buggedRoamer;
}

GameVersion _parseGame(String value) {
  return GameVersion.values.firstWhere((game) => game.jsonName == value);
}
