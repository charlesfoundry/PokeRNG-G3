enum GameVersion { emerald, fireRed, leafGreen }

extension GameVersionLabel on GameVersion {
  String get label {
    return switch (this) {
      GameVersion.emerald => 'Emerald',
      GameVersion.fireRed => 'FireRed',
      GameVersion.leafGreen => 'LeafGreen',
    };
  }

  String get jsonName {
    return switch (this) {
      GameVersion.emerald => 'emerald',
      GameVersion.fireRed => 'fireRed',
      GameVersion.leafGreen => 'leafGreen',
    };
  }

  String get defaultSeed {
    return switch (this) {
      GameVersion.emerald => '00000000',
      GameVersion.fireRed || GameVersion.leafGreen => '00000000',
    };
  }
}

class AppProfile {
  const AppProfile({
    required this.game,
    required this.tid,
    required this.sid,
    required this.defaultSeed,
  });

  factory AppProfile.initial() {
    return const AppProfile(
      game: GameVersion.emerald,
      tid: 0,
      sid: 0,
      defaultSeed: '00000000',
    );
  }

  final GameVersion game;
  final int tid;
  final int sid;
  final String defaultSeed;

  AppProfile copyWith({
    GameVersion? game,
    int? tid,
    int? sid,
    String? defaultSeed,
  }) {
    return AppProfile(
      game: game ?? this.game,
      tid: tid ?? this.tid,
      sid: sid ?? this.sid,
      defaultSeed: defaultSeed ?? this.defaultSeed,
    );
  }
}
